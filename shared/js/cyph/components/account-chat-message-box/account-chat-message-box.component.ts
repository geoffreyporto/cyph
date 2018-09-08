import {ChangeDetectionStrategy, Component, Input, ViewChild} from '@angular/core';
import {BaseProvider} from '../../base-provider';
import {ChatMessageValue} from '../../proto';
import {AccountService} from '../../services/account.service';
import {EnvService} from '../../services/env.service';
import {StringsService} from '../../services/strings.service';
import {calendarInviteReasons} from '../../verticals/telehealth/calendar-invite-reasons';
import {ChatMessageBoxInheritNgFormComponent} from '../chat-message-box-inherit-ng-form';


/**
 * Angular component for account chat message box UI.
 */
@Component({
	changeDetection: ChangeDetectionStrategy.OnPush,
	selector: 'cyph-account-chat-message-box',
	styleUrls: ['./account-chat-message-box.component.scss'],
	templateUrl: './account-chat-message-box.component.html'
})
export class AccountChatMessageBoxComponent extends BaseProvider {
	/** @see ChatMessageBoxComponent.calendarInviteFollowUp */
	@Input() public calendarInviteFollowUp?: boolean;

	/** @see ChatMessageBoxComponent.calendarInviteReasons */
	@Input() public calendarInviteReasons?: string[]	=
		this.envService.isTelehealth ?
			calendarInviteReasons :
			undefined
	;

	/** @see ChatMessageBoxInheritNgFormComponent */
	@ViewChild(ChatMessageBoxInheritNgFormComponent)
	public chatMessageBox?: ChatMessageBoxInheritNgFormComponent;

	/** @see ChatMessageValue.Types */
	public readonly chatMessageValueTypes: typeof ChatMessageValue.Types	=
		ChatMessageValue.Types
	;

	/** @see ChatMessageBoxComponent.customSendFunction */
	@Input() public customSendFunction?: () => Promise<void>;

	/** If true, will disable send button. */
	@Input() public disableSend: boolean		= false;

	/** @see ChatMessageBoxComponent.fileAccept */
	@Input() public fileAccept?: string;

	/** @see ChatMessageBoxComponent.messageType */
	@Input() public messageType: ChatMessageValue.Types	= ChatMessageValue.Types.Text;

	/** Shows header. */
	@Input() public showHeader: boolean			= false;

	/** @see ChatMessageBoxComponent.showUnreadCount */
	@Input() public showUnreadCount: boolean	= true;

	/** Submits form. */
	public async submit () : Promise<void> {
		if (this.chatMessageBox) {
			return this.chatMessageBox.send();
		}
	}

	constructor (
		/** @ignore */
		private readonly envService: EnvService,

		/** @see AccountService */
		public readonly accountService: AccountService,

		/** @see StringsService */
		public readonly stringsService: StringsService
	) {
		super();
	}
}
