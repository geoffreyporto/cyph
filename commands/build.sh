#!/bin/bash

outputDir="$PWD"
cd $(cd "$(dirname "$0")"; pwd)/..
rootDir="$PWD"


cloneworkingdir=''
test=''
watch=''
minify=''

if [ "${1}" == '--watch' ] ; then
	watch=true
	shift
else
	if [ "${1}" == '--prod' ] ; then
		shift
	else
		test=true
	fi
	if [ "${1}" == '--no-minify' ] ; then
		shift
	else
		minify=true
	fi
fi

if [ ! -d ~/.build ] ; then
	cloneworkingdir=true
fi

tsfilesRoot="${outputDir}"
if [ "${cloneworkingdir}" -o "${test}" -o "${watch}" -o "${outputDir}" == "${rootDir}" ] ; then
	tsfilesRoot="${rootDir}"
	outputDir="${rootDir}/shared"
fi

tsfiles="$(
	{
		cat cyph.com/*.html cyph.im/*.html | grep -oP "src=(['\"])/js/.*?\1";
		find ${outputDir}/js -name '*.ts' -not \( \
			-name '*.ngfactory.ts' \
			-or -name '*.ngmodule.ts' \
		\) -exec cat {} \; |
			grep -oP "importScripts\((['\"])/js/.*\1\)" \
		;
		echo cyph/analytics;
	} | \
		perl -pe "s/.*?['\"]\/js\/(.*)\.js.*/\1/g" |
		sort |
		uniq |
		grep -v 'Binary file' |
		grep -vP '^preload/global$' |
		grep -vP '^typings$' |
		xargs -I% bash -c "ls '${outputDir}/js/%.ts' > /dev/null 2>&1 && echo '%'"
)"

cd shared

scssfiles="$(
	find css -name '*.scss' -not -path 'css/bourbon/*' |
		perl -pe 's/css\/(.*)\.scss/\1/g' |
		tr '\n' ' '
)"


output=''

modulename () {
	m="$(echo ${1} | perl -pe 's/.*\/([^\/]+)$/\u$1/' | perl -pe 's/[^A-Za-z0-9](.)?/\u$1/g')"
	classM="$(grep -oiP "class\s+${m}" ${1}.ts | perl -pe 's/class\s+//')"

	if [ "${classM}" ] ; then
		echo "${classM}"
	else
		echo "${m}"
	fi
}

webpackname () {
	echo "${1}" | tr '/' '_'
}

tsbuild () {
	tmpdir="$(mktemp -d)"
	tmpjsdir="${tmpdir}/js"
	currentDir="../../..${PWD}"
	gettmpdir=''
	logtmpdir=''
	returntmpdir=''

	if [ "${1}" == '--log-tmp-dir' ] ; then
		shift
		logtmpdir=true
		returntmpdir=true
	elif [ "${1}" == '--get-tmp-dir' ] ; then
		shift
		gettmpdir=true
		returntmpdir=true
		echo "${tmpjsdir}"
	fi

	cp -rf .. "${tmpdir}/"

	node -e "
		const tsconfig	= JSON.parse(
			fs.readFileSync('tsconfig.json').toString().
				split('\n').
				filter(s => s.trim()[0] !== '/').
				join('\n')
		);

		/* Temporary, pending TS 2.1 */
		tsconfig.compilerOptions.alwaysStrict		= undefined;
		tsconfig.compilerOptions.lib				= undefined;
		tsconfig.compilerOptions.target				= 'es2015';

		/* For Angular AOT */
		tsconfig.compilerOptions.noUnusedParameters	= undefined;

		$(test "${watch}" && echo "
			tsconfig.compilerOptions.lib			= undefined;
			tsconfig.compilerOptions.target			= 'es2015';
		")

		$(test "${returntmpdir}" && echo "
			tsconfig.compilerOptions.outDir			= '.';
		")

		$(test "${returntmpdir}" || echo "
			tsconfig.compilerOptions.outDir			= '${currentDir}';
			tsconfig.angularCompilerOptions.genDir	= '${currentDir}';
		")

		tsconfig.files	= 'typings/index.d ${*}'.
			trim().
			split(/\s+/).
			map(f => f + '.ts')
		;

		fs.writeFileSync(
			'${tmpjsdir}/tsconfig.json',
			JSON.stringify(tsconfig)
		);
	"

	cd "${tmpjsdir}"

	if [ "${watch}" ] && [ ! "${gettmpdir}" ] ; then
		./node_modules/.bin/ngc -p .
	else
		output="${output}$(./node_modules/.bin/ngc -p . 2>&1)"
	fi

	cd "${currentDir}"

	if [ "${logtmpdir}" ] ; then
		for f in ${*} ; do
			echo "${tmpjsdir}" > "${f}.tmpdir"
		done
	fi
}

compile () {
	cd "${outputDir}"

	if [ "${cloneworkingdir}" ] ; then
		../commands/copyworkspace.sh --client-only ~/.build
		cd ~/.build/shared
	fi

	for f in $scssfiles ; do
		compileF () {
			scss -Icss "css/${f}.scss" |
				if [ "${minify}" ] ; then cleancss -s ; else cat - ; fi \
			> "${outputDir}/css/${f}.css"
		}

		if [ "${watch}" ] ; then
			compileF &
		else
			output="${output}$(compileF 2>&1)"
		fi
	done

	cd js

	if [ "${test}" ] ; then
		output="${output}$(../../commands/tslint.sh 2>&1)"
	else
		find . -type f -name '*.js' -exec rm {} \;

		node -e 'console.log(`
			self.translations = ${JSON.stringify(
				child_process.spawnSync("find", [
					"../../translations",
					"-name",
					"*.json"
				]).stdout.toString().
					split("\n").
					filter(s => s).
					map(file => ({
						key: file.split("/").slice(-1)[0].split(".")[0],
						value: JSON.parse(fs.readFileSync(file).toString())
					})).
					reduce((translations, o) => {
						translations[o.key]	= o.value;
						return translations;
					}, {})
			)};
		`.trim())' > translations.js
	fi

	if [ ! -d node_modules ] ; then
		mkdir node_modules
		cp -rf /node_modules/.bin /node_modules/@angular node_modules/
	fi

	nonmainfiles="$(echo "${tsfiles}" | grep -vP '/main$')"

	if [ "${watch}" ] ; then
		tsbuild --log-tmp-dir ${nonmainfiles} &
	else
		tsbuild ${nonmainfiles}
	fi

	for f in $(echo "${tsfiles}" | grep -P '/main$') ; do
		aotreplace () {
			sed -i 's|\./app.module|\./app.module.ngfactory|g' "${f}.ts"
			sed -i 's|AppModule|AppModuleNgFactory|g' "${f}.ts"
			sed -i 's|bootstrapModule|bootstrapModuleFactory|g' "${f}.ts"
		}

		if [ "${watch}" ] ; then
			{
				startdir="${PWD}"
				cd "$(tsbuild --get-tmp-dir "${f}")"
				aotreplace
				tsbuild --log-tmp-dir "${f}"
				mv "${f}.tmpdir" "${startdir}/${f}.tmpdir"
			} &
		else
			tsbuild "${f}"
			aotreplace
			tsbuild "${f}"
		fi
	done

	if [ ! "${test}" ] ; then
		tsbuild preload/global
		mv preload/global.js preload/global.js.tmp
		cat preload/global.js.tmp |
			babel --presets es2015 --compact false |
			if [ "${minify}" ] ; then uglifyjs ; else cat - ; fi \
		> "${outputDir}/js/preload/global.js"
		rm preload/global.js.tmp

		if [ "${minify}" ] ; then
			find . -name '*.js' -not \( \
				-name '*.ngfactory.js' \
				-or -name '*.ngmodule.js' \
			\) -exec cat {} \; |
				grep -oP '[A-Za-z_$][A-Za-z0-9_$]*' |
				sort |
				uniq |
				tr '\n' ' ' \
			> /tmp/mangle

			node -e "fs.writeFileSync(
				'/tmp/mangle.json',
				JSON.stringify(
					fs.readFileSync('/tmp/mangle').toString().trim().split(/\s+/)
				)
			)"
		fi

		for f in $tsfiles ; do
			m="$(modulename "${f}")"
			mainparent="$(echo "${f}" | sed 's|/main$||')"
			packdir="js/${mainparent}/pack"
			packdirfull="${outputDir}/${packdir}"
			records="${rootDir}/${mainparent}/webpack.json"
			htmlinput="${rootDir}/$(echo "${f}" | sed 's/\/.*//')/index.html"
			htmloutput="$(echo "${htmlinput}" | sed 's/index\.html$/.index.html/')"

			if [ "${watch}" ] ; then
				{
					waitForTmpdir () {
						while [ ! -f "${f}.tmpdir" ] ; do
							sleep 1
						done
					}

					currentDir="${PWD}"

					if [ "${m}" == 'Main' ] ; then
						cp -f "${htmlinput}" "${htmloutput}"
					fi

					waitForTmpdir
					cd "$(cat "${f}.tmpdir")"

					cat > webpack.js <<- EOM
						const webpack	= require('webpack');

						module.exports	= {
							entry: {
								app: './${f}'
							},
							externals: {
								mceliece: 'mceliece',
								ntru: 'ntru',
								rlwe: 'rlwe',
								sidh: 'sidh',
								sodium: 'sodium',
								sphincs: 'sphincs',
								supersphincs: 'supersphincs'
							},
							output: {
								filename: '${currentDir}/${f}.js.tmp',
								library: '${m}',
								libraryTarget: 'var'
							}
						};
					EOM

					webpack --config webpack.js

					echo
				} &

				continue
			fi

			if [ "${m}" == 'Main' ] ; then
				rm -rf $packdirfull 2> /dev/null
				mkdir $packdirfull
			fi

			# Don't use ".js" file extension for Webpack outputs. No idea
			# why right now, but it breaks the module imports in Session.
			node -e "
				const cheerio	= require('cheerio');
				const webpack	= require('webpack');

				webpack({
					entry: {
						main: './${f}'
					},
					externals: {
						mceliece: 'mceliece',
						ntru: 'ntru',
						rlwe: 'rlwe',
						sidh: 'sidh',
						sodium: 'sodium',
						sphincs: 'sphincs',
						supersphincs: 'supersphincs'
					},
					module: {
						rules: [
							{
								test: /\.js(\.tmp)?$/,
								use: [
									{
										loader: 'babel-loader',
										options: {
											compact: false,
											presets: [
												['es2015', {modules: false}]
											]
										}
									}
								]
							}
						]
					},
					output: {
						$(test "${m}" == 'Main' || echo "
							filename: './${f}.js.tmp',
							library: '${m}',
							libraryTarget: 'var'
						")
						$(test "${m}" == 'Main' && echo "
							filename: '[chunkhash].js',
							chunkFilename: '[chunkhash].js',
							path: '${packdirfull}'
						")
					},
					plugins: [
						$(test "${minify}" && echo "
							new webpack.LoaderOptionsPlugin({
								debug: false,
								minimize: true
							}),
							new webpack.optimize.UglifyJsPlugin({
								compress: false,
								mangle: {
									except: JSON.parse(
										fs.readFileSync('/tmp/mangle.json').toString()
									)
								},
								output: {
									comments: false
								},
								sourceMap: false,
								test: /\.js(\.tmp)?$/
							}),
						")
						$(test "${m}" == 'Main' && {
							echo "
								new webpack.optimize.AggressiveSplittingPlugin({
									minSize: 30000,
									maxSize: 50000
								}),
							";
							echo "
								new webpack.optimize.CommonsChunkPlugin({
									name: 'init',
									minChunks: Infinity
								})
							";
						})
					],
					$(test "${m}" == 'Main' && echo "
						recordsOutputPath: '${records}'
					")
				}, (err, stats) => {$(test "${m}" == 'Main' && echo "
					if (err) {
						throw err;
					}

					const \$	= cheerio.load(fs.readFileSync('${htmlinput}').toString());

					\$('script[src=\"/js/${f}.js\"]').remove();

					for (const chunk of stats.compilation.entrypoints.main.chunks) {
						for (const file of chunk.files) {
							\$('body').append( \`<script src='/${packdir}/\${file}'></script>\`);
						}
					}

					fs.writeFileSync('${htmloutput}', \$.html().trim());
				")});
			"
		done

		for f in $tsfiles ; do
			m="$(modulename "${f}")"

			if [ "${watch}" ] ; then
				while [ ! -f "${f}.js.tmp" ] ; do
					sleep 1
				done

				if [ "${m}" == 'Main' ] ; then
					mv "${f}.js.tmp" "${outputDir}/js/${f}.js"
				fi
			fi

			if [ "${m}" == 'Main' ] ; then
				continue
			fi

			{
				echo '(function () {';
				cat "${f}.js.tmp";
				test "${m}" == 'Main' || echo "
					self.${m}	= ${m};

					var keys	= Object.keys(${m});
					for (var i = 0 ; i < keys.length ; ++i) {
						var key		= keys[i];
						self[key]	= ${m}[key];
					}
				" |
					if [ "${minify}" ] ; then uglifyjs ; else cat - ; fi \
				;
				echo '})();';
			} \
				> "${outputDir}/js/${f}.js"

			rm "${f}.js.tmp"
		done

		if [ "${watch}" ] ; then
			return
		fi

		for js in $(find . -type f -name '*.js' -not \( \
			-path './preload/global.js' \
			-or -name 'translations.js' \
			-or -path './*/pack/*' \
		\)) ; do
			delete=true
			for f in $tsfiles ; do
				if [ "${js}" == "./${f}.js" ] ; then
					delete=''
				fi
			done
			if [ "${delete}" ] ; then
				rm "${js}"
			fi
		done

		find "${outputDir}/js" -type f -name '*.js' -not -path '*/node_modules/*' -exec \
			sed -i 's|use strict||g' {} \
		\;
	fi
}

litedeploy () {
	cd ~/.litedeploy

	version="lite-${username}-${branch}"
	deployedBackend="https://${version}-dot-cyphme.appspot.com"
	localBackend='${locationData.protocol}//${locationData.hostname}:42000'

	sed -i "s|staging|${version}|g" default/config.go
	sed -i "s|${localBackend}|${deployedBackend}|g" cyph.im/js/cyph.im/main.js
	cat cyph.im/cyph-im.yaml | perl -pe 's/(- url: .*)/\1\n  login: admin/g' > yaml.new
	mv yaml.new cyph.im/cyph-im.yaml

	gcloud app deploy --quiet --no-promote --project cyphme --version $version */*.yaml

	cd
	rm -rf ~/.litedeploy

	echo -e "\n\n\nFinished deploying\n\n"
}

if [ "${watch}" ] ; then
	eval "$(${rootDir}/commands/getgitdata.sh)"

	liteDeployInterval=1800 # 30 minutes
	SECONDS=$liteDeployInterval

	while true ; do
		start="$(date +%s)"
		echo -e '\n\n\nBuilding JS/CSS\n\n'
		compile
		echo -e "\n\n\nFinished building JS/CSS ($(expr $(date +%s) - $start)s)\n\n"

		#if [ $SECONDS -gt $liteDeployInterval -a ! -d ~/.litedeploy ] ; then
		#	echo -e "\n\n\nDeploying to lite env\n\n"
		#	mkdir ~/.litedeploy
		#	cp -rf "${rootDir}/default" "${rootDir}/cyph.im" ~/.litedeploy/
		#	litedeploy &
		#	SECONDS=0
		#fi

		cd "${rootDir}/shared"

		while true ; do
			fsevent="$(
				inotifywait -r --exclude '(bourbon|sed.*|.*\.(css|js|map|tmp))$' css js templates
			)"
			if ! echo "${fsevent}" | grep -P '(OPEN|ISDIR)' > /dev/null ; then
				break
			fi
		done
	done
else
	compile
fi

echo -e "${output}"
exit ${#output}
