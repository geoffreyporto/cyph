import {ChangeDetectionStrategy, Component} from '@angular/core';
import {BaseProvider} from '../../base-provider';
import {AccountPostsService} from '../../services/account-posts.service';
import {StringsService} from '../../services/strings.service';

/**
 * Angular component for account post feed UI.
 */
@Component({
	changeDetection: ChangeDetectionStrategy.OnPush,
	selector: 'cyph-account-post-feed',
	styleUrls: ['./account-post-feed.component.scss'],
	templateUrl: './account-post-feed.component.html'
})
export class AccountPostFeedComponent extends BaseProvider {
	constructor (
		/** @see AccountPostsService */
		public readonly accountPostsService: AccountPostsService,

		/** @see StringsService */
		public readonly stringsService: StringsService
	) {
		super();
	}
}
