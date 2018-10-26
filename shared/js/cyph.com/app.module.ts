/* tslint:disable:no-import-side-effect no-reference */

/// <reference path="../typings/index.d.ts" />

import '../standalone/global';
import '../standalone/node-polyfills';

import 'hammerjs';

import {HttpClient} from '@angular/common/http';
import {DoBootstrap, Injector, NgModule, NgZone} from '@angular/core';
import {createCustomElement} from '@angular/elements';
import {DomSanitizer} from '@angular/platform-browser';
import {CheckoutComponent} from '../cyph/components/checkout';
import {CyphSharedModule} from '../cyph/modules/cyph-shared.module';
import {AnalyticsService} from '../cyph/services/analytics.service';
import {DialogService} from '../cyph/services/dialog.service';
import {MaterialDialogService} from '../cyph/services/material-dialog.service';
import {email} from '../cyph/util/email';
import {resolveStaticServices} from '../cyph/util/static-services';


/**
 * Angular module for Cyph home page.
 */
@NgModule({
	declarations: [
		CheckoutComponent
	],
	entryComponents: [
		CheckoutComponent
	],
	imports: [
		CyphSharedModule
	],
	providers: [
		AnalyticsService,
		{
			provide: DialogService,
			useClass: MaterialDialogService
		}
	]
})
export class AppModule implements DoBootstrap {
	/** @inheritdoc */
	public ngDoBootstrap () : void {
		customElements.define(
			'cyph-checkout',
			createCustomElement(CheckoutComponent, {injector: this.injector})
		);
	}

	constructor (
		domSanitizer: DomSanitizer,
		httpClient: HttpClient,
		ngZone: NgZone,
		_ANALYTICS_SERVICE: AnalyticsService,
		dialogService: DialogService,

		/** @ignore */
		private readonly injector: Injector
	) {
		(<any> self).sendEmail	= email;

		resolveStaticServices({
			dialogService,
			domSanitizer,
			httpClient,
			ngZone
		});
	}
}
