import {AsyncPipe} from '@angular/common';
import {ChangeDetectorRef, OnDestroy, Pipe, PipeTransform} from '@angular/core';
import {Observable} from 'rxjs';
import {Async} from '../async-type';

/** Replaces the built-in AsyncPipe's "empty" value of null with undefined. */
@Pipe({
	name: 'await',
	pure: false
})
export class AwaitPipe implements OnDestroy, PipeTransform {
	/** @see AsyncPipe */
	private readonly asyncPipe: AsyncPipe;

	/** @inheritDoc */
	public ngOnDestroy () : void {
		this.asyncPipe.ngOnDestroy();
	}

	/** @inheritDoc */
	/* eslint-disable-next-line no-null/no-null */
	public transform<T> (obj: undefined | null) : undefined;
	public transform<T> (obj: T) : T;
	public transform<T> (obj: Promise<T>) : T | undefined;
	public transform<T> (obj: Observable<T>) : T | undefined;
	/* eslint-disable-next-line no-null/no-null */
	public transform<T> (obj: Async<T | undefined | null>) : T | undefined {
		const retVal =
			obj instanceof Promise ?
				this.asyncPipe.transform(obj) :
			obj instanceof Observable ?
				this.asyncPipe.transform(obj) :
				obj;

		/* eslint-disable-next-line no-null/no-null */
		return retVal === null ? undefined : retVal;
	}

	constructor (changeDetectorRef: ChangeDetectorRef) {
		this.asyncPipe = new AsyncPipe(changeDetectorRef);
	}
}
