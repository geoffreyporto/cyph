#!/bin/bash


cd $(cd "$(dirname "$0")" ; pwd)/..


serviceWorker=''
if [ "${1}" == '--service-worker' ] ; then
	serviceWorker=true
	shift
fi

test=''
if [ "${1}" == '--test' ] ; then
	test=true
	shift
fi


checkfail () {
	if (( $? )) ; then
		exit 1
	fi
}


if [ -f shared/assets/frozen ] ; then
	log 'Assets frozen'
	exit
fi


find shared/js -type f -name '*.js' -not -path 'shared/js/proto/*' -exec rm {} \;


nodeModulesAssets="$(
	grep -roP "importScripts\('/assets/node_modules/.*?\.js'\)" shared/js |
		perl -pe "s/^.*?'\/assets\/node_modules\/(.*?)\.js'.*/\1/g" |
		sort |
		uniq
)"

typescriptAssets="$(
	{
		echo cyph/crypto/native-web-crypto-polyfill;
		echo cyph/crypto/potassium/index;
		echo cyph/proto/index;
		echo cyph/util/index;
		echo standalone/analytics;
		echo standalone/node-polyfills;
		grep -roP "importScripts\('/assets/js/.*?\.js'\)" shared/js |
			perl -pe "s/^.*?'\/assets\/js\/(.*?)\.js'.*/\1/g" |
			grep -vP '^standalone/global$' \
		;
	} |
		sort |
		uniq
)"

scssAssets="$(
	{
		echo app;
		grep -oP "href='/assets/css/.*?\.css'" */src/index.html |
			perl -pe "s/^.*?'\/assets\/css\/(.*?)\.css'.*/\1/g" \
		;
	} |
		sort |
		uniq
)"

hash="${serviceWorker}${test}$(
	cat \
		commands/buildunbundledassets.sh \
		types.proto \
		$(echo "${nodeModulesAssets}" | perl -pe 's/([^\s]+)/\/node_modules\/\1.js/g') \
		$(find shared/js -type f -name '*.ts' -not \( \
			-name '*.d.ts' -or \
			-name '*.spec.ts' -or \
			-path 'shared/js/environments/*' \
		\)) \
		$(find shared/css -type f -name '*.scss') \
	|
		shasum -a 512 |
		awk '{print $1}'
)"


cd shared/assets

if [ -f unbundled.hash ] && [ "${hash}" == "$(cat unbundled.hash)" ] ; then
	exit 0
fi

rm -rf node_modules js css 2> /dev/null
mkdir node_modules js css


../../commands/protobuf.sh

if [ "${serviceWorker}" ] || [ "${test}" ] ; then
	node -e 'console.log(
		fs.readFileSync("../../websign/serviceworker.js").toString().replace(
			"/* Redirect non-whitelisted paths in this origin */",
			"if (url.indexOf(\".\") > -1) { urls[url] = true; }"
		)
	)' \
		> serviceworker.js
fi


cd node_modules

for f in ${nodeModulesAssets} ; do
	mkdir -p "$(echo "${f}" | perl -pe 's/(.*)\/[^\/]+$/\1/')" 2> /dev/null

	path="/node_modules/${f}.js"
	if [ -f "/node_modules/${f}.min.js" ] ; then
		path="/node_modules/${f}.min.js"
	fi

	uglifyjs "${path}" -cmo "${f}.js"
done


cd ../js

node -e "
	const tsconfig	= JSON.parse(
		fs.readFileSync('../../js/tsconfig.json').toString().
			split('\n').
			filter(s => s.trim()[0] !== '/').
			join('\n')
	);

	tsconfig.compilerOptions.baseUrl	= '../../js';
	tsconfig.compilerOptions.rootDir	= '../../js';
	tsconfig.compilerOptions.outDir		= '.';

	tsconfig.files	= [
		'../../js/standalone/global.ts',
		'../../js/typings/index.d.ts'
	];

	for (const k of Object.keys(tsconfig.compilerOptions.paths)) {
		tsconfig.compilerOptions.paths[k]	=
			tsconfig.compilerOptions.paths[k].map(s =>
				s.replace(/^js\//, '')
			)
		;
	}

	fs.writeFileSync('tsconfig.json', JSON.stringify(tsconfig));
"

tsc -p .
checkfail
uglifyjs standalone/global.js -o standalone/global.js
checkfail

for f in ${typescriptAssets} ; do
	m="$(echo ${f} | perl -pe 's/.*\/([^\/]+)$/\u$1/' | perl -pe 's/[^A-Za-z0-9](.)?/\u$1/g')"

	cat > webpack.js <<- EOM
		const {TsConfigPathsPlugin}	= require('awesome-typescript-loader');
		const path					= require('path');
		const UglifyJsPlugin		= require('uglifyjs-webpack-plugin');
		const {mangleExceptions}	= require('../../../commands/mangleexceptions');

		module.exports	= {
			entry: {
				app: '../../js/${f}'
			},
			mode: 'none',
			module: {
				rules: [
					{
						test: /\.ts$/,
						use: [{loader: 'awesome-typescript-loader'}]
					}
				]
			},
			output: {
				filename: '${f}.js',
				library: '${m}',
				libraryTarget: 'var',
				path: '${PWD}'
			},
			plugins: [
				$(test "${test}" || echo "
					new UglifyJsPlugin({
						cache: true,
						extractComments: false,
						parallel: true,
						sourceMap: false,
						uglifyOptions: {
							compress: false /* {
								inline: 3,
								passes: 3,
								pure_getters: true,
								sequences: false,
								typeofs: false
							} */,
							ecma: 5,
							ie8: false,
							mangle: {
								reserved: mangleExceptions
							},
							output: {
								ascii_only: true,
								comments: false,
								webkit: true
							},
							safari10: true,
							warnings: false
						}
					})
				")
			],
			resolve: {
				alias: {
					jquery: path.resolve(__dirname, '../../js/native/externals/jquery.ts')
				},
				extensions: ['.js', '.ts'],
				plugins: [
					new TsConfigPathsPlugin({
						compiler: 'typescript',
						configFileName: 'tsconfig.json'
					})
				]
			}
		};
	EOM

	webpack --config webpack.js
	checkfail
	rm webpack.js

	{
		echo '(function () {';
		cat "${f}.js";
		echo "
			self.${m}	= ${m};

			var keys	= Object.keys(${m});
			for (var i = 0 ; i < keys.length ; ++i) {
				var key		= keys[i];
				self[key]	= ${m}[key];
			}
		" |
			uglifyjs \
		;
		echo '})();';
	} \
		> "${f}.js.tmp"

	checkfail

	mv "${f}.js.tmp" "${f}.js"

	echo
	ls -lh "${f}.js"
	echo -e '\n'
done


cd ../css

cp -rf ../../css/* ./
grep -rl "@import '~" | xargs -I% sed -i "s|@import '~|@import '/node_modules/|g" %

for f in ${scssAssets} ; do
	scss "${f}.scss" "${f}.css"
	checkfail
	cleancss --inline none "${f}.css" -o "${f}.css"
	checkfail
done


cd ..
find . -type f -name '*.js' -exec sed -i 's|use strict||g' {} \;
echo "${hash}" > unbundled.hash
