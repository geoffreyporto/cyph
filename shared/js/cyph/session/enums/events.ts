/**
 * Session-related events that may be handled throughout the codes.
 */
export class Events {
	/** @see Events */
	public readonly abort: string				= 'abort';

	/** @see Events */
	public readonly beginChat: string			= 'beginChat';

	/** @see Events */
	public readonly beginChatComplete: string	= 'beginChatComplete';

	/** @see Events */
	public readonly beginWaiting: string		= 'beginWaiting';

	/** @see Events */
	public readonly castle: string				= 'castle';

	/** @see Events */
	public readonly closeChat: string			= 'closeChat';

	/** @see Events */
	public readonly connect: string				= 'connect';

	/** @see Events */
	public readonly connectFailure: string		= 'connectFailure';

	/** @see Events */
	public readonly cyphertext: string			= 'cyphertext';

	/** @see Events */
	public readonly cyphNotFound: string		= 'cyphNotFound';

	/** @see Events */
	public readonly filesUI: string				= 'filesUI';

	/** @see Events */
	public readonly newCyph: string				= 'newCyph';

	/** @see Events */
	public readonly p2pUI: string				= 'p2pUI';

	constructor () {}
}

/** @see Events */
export const events	= new Events();
