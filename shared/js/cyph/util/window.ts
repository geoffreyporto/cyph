import {env} from '../env';
import {MaybePromise} from '../maybe-promise-type';

/** Opens the specified URL in a new window. */
export const openWindow = async (
	url: string | MaybePromise<string>[]
) : Promise<void> => {
	/* TODO: HANDLE NATIVE */
	if (!env.isWeb) {
		return;
	}

	if (url instanceof Array) {
		url = (await Promise.all(url)).join('');
	}

	if (env.isCordovaDesktop) {
		/* eslint-disable-next-line @typescript-eslint/tslint/config */
		window.open(url);
		return;
	}

	const a = document.createElement('a');
	a.href = url;
	a.target = '_blank';
	a.rel = 'noopener';
	a.click();
};

/** Reloads window, or performs equivalent behavior depending on platform. */
export const reloadWindow = () : void => {
	if (env.isCordovaDesktop && typeof cordovaRequire === 'function') {
		const {remote} = cordovaRequire('electron');
		remote.app.quit();
	}
	else if (env.isWeb) {
		location.reload();
	}
	else {
		/* TODO: HANDLE NATIVE */
	}
};
