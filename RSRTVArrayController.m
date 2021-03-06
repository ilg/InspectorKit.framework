// RSRTVArrayController.m
//
// RSRTV stands for Red Sweater Reordering Table View Controller.
//
// Based on code from Apple's DragNDropOutlineView example, which granted 
// unlimited modification and redistribution rights, provided Apple not be held legally liable.
//
// Differences between this file and the original are © 2006 Red Sweater Software.
//
// You are granted a non-exclusive, unlimited license to use, reproduce, modify and 
// redistribute this source code in any form provided that you agree to NOT hold liable 
// Red Sweater Software or Daniel Jalkut for any damages caused by such use.
//

#import "RSRTVArrayController.h"

NSString *kRSRTVMovedRowsType = @"com.red-sweater.RSRTVArrayController";

@implementation RSRTVArrayController

- (void) awakeFromNib
{
	[oTableView registerForDraggedTypes:[NSArray arrayWithObjects:kRSRTVMovedRowsType, nil]];
	[self setDraggingEnabled:YES];	
}

//  draggingEnabled 
- (BOOL) draggingEnabled
{
    return mDraggingEnabled;
}

- (void) setDraggingEnabled: (BOOL) flag
{
    mDraggingEnabled = flag;
}

- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard
{	
	if ([self draggingEnabled] == YES)
	{
		// Declare our "moved rows" drag type
		[pboard declareTypes:[NSArray arrayWithObjects:kRSRTVMovedRowsType, nil] owner:self];
		
		// Just add the rows themselves to the pasteboard
		[pboard setPropertyList:rows forType:kRSRTVMovedRowsType];
	}
	
    return [self draggingEnabled];
}

- (BOOL) tableObjectsSupportCopying
{
	return [[[self arrangedObjects] objectAtIndex:0] conformsToProtocol:@protocol(NSCopying)];
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSUInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
    NSDragOperation dragOp = NSDragOperationNone;
    
    // if drag source is our own table view, it's a move or a copy
    if ([info draggingSource] == tv)
	{		
		// At a minimum, allow move
		dragOp =  NSDragOperationMove;

		// Only expose the copy method if objects in this table appear to support copying...
		if (([info draggingSourceOperationMask] == NSDragOperationCopy) && ([self tableObjectsSupportCopying] == YES))
		{
			dragOp = NSDragOperationCopy;
		}
    }
	
    // we want to put the object at, not over,
    // the current row (contrast NSTableViewDropOn) 
    [tv setDropRow:row dropOperation:NSTableViewDropAbove];
	
    return dragOp;
}

- (BOOL)tableView:(NSTableView*)tv acceptDrop:(id <NSDraggingInfo>)info row:(NSUInteger)row dropOperation:(NSTableViewDropOperation)op
{
    if (row < 0)
	{
		row = 0;
	}
    
    // if drag source is self, it's a move or copy
    if ([info draggingSource] == tv)
    {		
		NSArray *rows = [[info draggingPasteboard] propertyListForType:kRSRTVMovedRowsType];
		NSIndexSet *indexSet = [self indexSetFromRows:rows];
		NSUInteger rowsAbove = 0;
		
		if (([info draggingSourceOperationMask] == NSDragOperationCopy) && [self tableObjectsSupportCopying])
		{
			[self copyObjectsInArrangedObjectsFromIndexes:indexSet toIndex:row];
		}
		else
		{
			[self moveObjectsInArrangedObjectsFromIndexes:indexSet toIndex:row];

			// set selected rows to those that were just moved
			// Need to work out what moved where to determine proper selection...
			rowsAbove = [self rowsAboveRow:row inIndexSet:indexSet];
		}
		
		NSRange range = NSMakeRange(row - rowsAbove, [indexSet count]);
		indexSet = [NSIndexSet indexSetWithIndexesInRange:range];
		[self setSelectionIndexes:indexSet];
		
		return YES;
    }
	
    return NO;
}

-(void) copyObjectsInArrangedObjectsFromIndexes:(NSIndexSet*)indexSet toIndex:(NSUInteger)insertIndex
{	
    NSArray		*objects = [self arrangedObjects];
	NSUInteger	copyFromIndex = [indexSet lastIndex];
	
    NSUInteger	aboveInsertIndexCount = 0;
    id			object;
    NSUInteger	copyIndex;
	
    while (NSNotFound != copyFromIndex)
	{
		if (copyFromIndex >= insertIndex)
		{
			copyIndex = copyFromIndex + aboveInsertIndexCount;
			aboveInsertIndexCount += 1;
		}
		else
		{
			copyIndex = copyFromIndex;
//			insertIndex -= 1;
		}
		object = [objects objectAtIndex:copyIndex];
		[self insertObject:[object copy] atArrangedObjectIndex:insertIndex];
		
		copyFromIndex = [indexSet indexLessThanIndex:copyFromIndex];
    }
}

-(void) moveObjectsInArrangedObjectsFromIndexes:(NSIndexSet*)indexSet toIndex:(NSUInteger)insertIndex
{
	
    NSArray		*objects = [self arrangedObjects];
	NSUInteger	index = [indexSet lastIndex];
	
    NSUInteger	aboveInsertIndexCount = 0;
    id			object;
    NSUInteger	removeIndex;
	
    while (NSNotFound != index)
	{
		if (index >= insertIndex)
		{
			removeIndex = index + aboveInsertIndexCount;
			aboveInsertIndexCount += 1;
		}
		else
		{
			removeIndex = index;
			insertIndex -= 1;
		}
		
		// Get the object we're moving
		object = [objects objectAtIndex:removeIndex];

		// In case nobody else is retaining the object, we need to keep it alive while we move it 		
		[object retain];
		[self removeObjectAtArrangedObjectIndex:removeIndex];
		[self insertObject:object atArrangedObjectIndex:insertIndex];
		[object release];
		
		index = [indexSet indexLessThanIndex:index];
    }
}


- (NSIndexSet *)indexSetFromRows:(NSArray *)rows
{
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    NSEnumerator *rowEnumerator = [rows objectEnumerator];
    NSNumber *idx;
    while (idx = [rowEnumerator nextObject])
    {
		[indexSet addIndex:[idx intValue]];
    }
    return indexSet;
}


- (NSUInteger)rowsAboveRow:(NSUInteger)row inIndexSet:(NSIndexSet *)indexSet
{
    NSUInteger currentIndex = [indexSet firstIndex];
    NSUInteger i = 0;
    while (currentIndex != NSNotFound)
    {
		if (currentIndex < row) { i++; }
		currentIndex = [indexSet indexGreaterThanIndex:currentIndex];
    }
    return i;
}

// WORK AROUND an NSTableView or something bug where the collapsed column leaves its contents drawn
// in the cornerView area when resized... by aggressively redrawing the cornerview whenever the 
// columns resize, we can assure a clean slate.

- (void)tableViewColumnDidResize:(NSNotification *)notification
{
	// Pay attention to column resizes and aggressively force the tableview's 
	// cornerview to redraw.
	[[oTableView cornerView] setNeedsDisplay:YES];
}

@end
