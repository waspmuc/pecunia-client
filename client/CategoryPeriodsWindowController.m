//
//  CategoryPeriodsWindowController.m
//  Pecunia
//
//  Created by Frank Emminghaus on 09.11.10.
//  Copyright 2010 Frank Emminghaus. All rights reserved.
//

#import "CategoryPeriodsWindowController.h"
#import "ShortDate.h"
#import "MCEMOutlineViewLayout.h"
#import "CategoryReportingNode.h"

@implementation CategoryPeriodsWindowController

@synthesize minDate;
@synthesize maxDate;

@synthesize categoryHistory;
@synthesize dates;
@synthesize selectedDates;
@synthesize fromDate;
@synthesize toDate;
@synthesize dataRoot;
@synthesize periodRoot;
@synthesize formatter;

-(id)init
{
	self = [super init ];
	if (self == nil) return nil;
	
	histType = cat_histtype_month;
	self.dates = [NSMutableArray arrayWithCapacity:20];
	self.selectedDates = [NSMutableArray arrayWithCapacity:20];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults ];
	NSDictionary *values = [userDefaults objectForKey: @"catPeriodDefaults" ];
	if(values) {
		if ([values objectForKey: @"type" ]) {
			histType = (CatHistoryType)[[values objectForKey: @"type" ] intValue ];
		}
		if ([values objectForKey: @"fromDate" ]) {
			self.fromDate = [ShortDate dateWithDate: [values objectForKey: @"fromDate" ] ];
		}
		if ([values objectForKey: @"toDate" ]) {
			self.toDate = [ShortDate dateWithDate: [values objectForKey: @"toDate" ] ];
		}
	}
	
	if (self.fromDate == nil) {
		self.fromDate = [[ShortDate currentDate ] firstDayInYear ];
	}
	if (self.toDate == nil) {
		self.toDate = [[ShortDate currentDate ] firstDayInMonth ];
	}
	
	return self;
}

-(void)awakeFromNib
{	
	NSSortDescriptor	*sd = [[[NSSortDescriptor alloc] initWithKey:@"self" ascending:NO] autorelease];
	NSArray				*sds = [NSArray arrayWithObject:sd];
	[catPeriodDatesController setSortDescriptors:sds ];
	
	// init number formatter
	self.formatter = [[[NSNumberFormatter alloc ] init ] autorelease ];
	[self.formatter setNumberStyle: NSNumberFormatterCurrencyStyle ];
	[self.formatter setLocale:[NSLocale currentLocale ] ];
	[self.formatter setCurrencySymbol:@"" ];
		
	self.dataRoot = [[Category catRoot ] categoryHistoryWithType:cat_histtype_month ];
	[self getMinMaxDatesForNode:self.dataRoot ];
	
	if ([fromDate compare:minDate ] == NSOrderedAscending) {
		self.fromDate = self.minDate;
	}
	if ([toDate compare:maxDate ] == NSOrderedDescending) {
		self.toDate = self.maxDate;
	}
	
	[categoryController setContent:self.dataRoot ];
	[self updatePeriodDates ];
	[self adjustDates ];
	[self updateData ];
	[self performSelector: @selector(restoreCategoryView) withObject: nil afterDelay: 0.0];
}

-(void)getMinMaxDatesForNode: (CategoryReportingNode*)node
{
	for(CategoryReportingNode *child in node.children) {
		[self getMinMaxDatesForNode: child ];
	}
	
	NSArray *keys = [node.values allKeys ];
	for(ShortDate *date in keys) {
		if (minDate == nil || [date compare:minDate ] == NSOrderedAscending	) {
			self.minDate = date;
		}
		if (maxDate == nil || [date compare:maxDate ] == NSOrderedDescending) {
			self.maxDate = date;
		}
	}	
}

-(void)updatePeriodDates
{
	[self.dates removeAllObjects ];
	ShortDate *refDate = [self periodRefDateForDate:minDate ];
	
	while ([refDate compare:maxDate ] != NSOrderedDescending) {
		[self.dates addObject:refDate ];
		switch (histType) {
			case cat_histtype_year:
				refDate = [refDate dateByAddingYears:1 ];
				break;
			case cat_histtype_quarter:
				refDate = [refDate dateByAddingMonths:3 ];
				break;
			default:
				refDate = [refDate dateByAddingMonths:1 ];
				break;
		}
	} //while
	
	[catPeriodDatesController setContent:self.dates ];
	[catPeriodDatesController rearrangeObjects ];
}

-(void)restoreCategoryView
{
	BOOL found = TRUE;
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults ];
	NSArray* urs = [defaults objectForKey: [NSString stringWithFormat: @"NSOutlineView Items %@", [categoryView autosaveName ]]];
	NSMutableArray* uris = [urs mutableCopy ];
	
	while([uris count ] > 0 && found == TRUE) {
		int i, idx;
		
		found = FALSE;
		for(i=0; i<[categoryView numberOfRows ]; i++) {
			NSString* uri = [[[categoryView itemAtRow: i ]  representedObject] name ];
			idx = [uris indexOfObject: uri ];
			if(idx != NSNotFound) {
				[uris removeObjectAtIndex: idx ];
				id item = [categoryView itemAtRow: i];
				[categoryView expandItem: item];
				found = TRUE;
			}
		}
	}
	if(found == FALSE) [defaults setObject: nil forKey: [NSString stringWithFormat: @"NSOutlineView Items %@", [categoryView autosaveName ]] ];
	
	[categoryView restoreLayout ];
}

-(NSString*)keyForDate:(ShortDate*)date
{
	return [NSString stringWithFormat:@"%d%d%d", date.year, date.month, date.day ]; 
}

-(ShortDate*)periodRefDateForDate:(ShortDate*)date
{
	switch (histType) {
		case cat_histtype_year: return [date firstDayInYear ];
		case cat_histtype_quarter: return [date firstDayInQuarter ];
		default: return date;
	}
}

-(void)updatePeriodDataForNode:(CategoryReportingNode*)node
{
	for(CategoryReportingNode *child in node.children) {
		[self updatePeriodDataForNode: child ];
	}
	
	NSArray *keys = [node.values allKeys ];
	
	[node.periodValues removeAllObjects ]; 
	for(ShortDate *date in keys) {
		ShortDate *refDate = [self periodRefDateForDate: date ];
		
		// add up values
		if ([refDate compare: fromDate ] != NSOrderedAscending && [refDate compare:toDate ] != NSOrderedDescending) {
			NSDecimalNumber *num = [node.periodValues objectForKey:[self keyForDate:refDate ]];
			if (num) {
				num = [num decimalNumberByAdding:[node.values objectForKey:date ] ];
			} else {
				num = [node.values objectForKey:date ];
			}
			[node.periodValues setObject:num forKey:[self keyForDate:refDate ] ];
		}
		
		// check that there is an entry for each date
		refDate = fromDate;
		while ([refDate compare:toDate ] != NSOrderedDescending) {
			NSDecimalNumber *num = [node.periodValues objectForKey:[self keyForDate:refDate ] ];
			if (num == nil) {
				[node.periodValues setObject:[NSDecimalNumber zero ] forKey:[self keyForDate:refDate ] ];
			}
			switch (histType) {
				case cat_histtype_year:
					refDate = [refDate dateByAddingYears:1 ];
					break;
				case cat_histtype_quarter:
					refDate = [refDate dateByAddingMonths:3 ];
					break;
				default:
					refDate = [refDate dateByAddingMonths:1 ];
					break;
			}
		} //while
	}
}

-(void)updateData
{
	// delete all table columns
	NSArray *cols = [[categoryView tableColumns ] copy ];
	for(NSTableColumn *col in cols) {
		if ([[col identifier ] isEqualToString: @"category" ] == NO) [categoryView removeTableColumn:col ];
	}
	
	[self updatePeriodDataForNode: self.dataRoot ];
	
	// calculate selected days
	[self.selectedDates removeAllObjects ];
	ShortDate *refDate = self.fromDate;
	while ([refDate compare:toDate ] != NSOrderedDescending) {
		[self.selectedDates addObject:refDate ];
		switch (histType) {
			case cat_histtype_year:
				refDate = [refDate dateByAddingYears:1 ];
				break;
			case cat_histtype_quarter:
				refDate = [refDate dateByAddingMonths:3 ];
				break;
			default:
				refDate = [refDate dateByAddingMonths:1 ];
				break;
		}
	} //while
		
	// and add current columns again
	for(ShortDate *date in selectedDates) {
		NSString *identifier = [self keyForDate:date ];
		NSString *title;
		
		switch (histType) {
			case cat_histtype_year: title = [date yearDescription ]; break;
			case cat_histtype_quarter: title = [date quarterYearDescription ]; break;
			default: title = [date monthYearDescription ]; break;
		}				
		
		NSTableColumn *column = [[NSTableColumn alloc ] initWithIdentifier:identifier ];
		[[column headerCell ] setStringValue:title ];
		[[column dataCell ] setFormatter:self.formatter ];
		[[column dataCell ] setAlignment:NSRightTextAlignment ];
		[categoryView addTableColumn:column ];
		NSString *keyPath = [@"arrangedObjects.periodValues." stringByAppendingString:identifier ];
		[column bind:@"value" toObject:categoryController withKeyPath:keyPath options: nil ];
	}
}

-(Category*)currentSelection
{
	NSArray* sel = [categoryController selectedObjects ];
	if(sel == nil || [sel count ] != 1) return nil;
	return [sel objectAtIndex: 0 ];
}

-(void)adjustDates
{
	if ([dates count ] == 0) return;
	ShortDate *firstDate = [dates objectAtIndex:0 ];
	ShortDate *lastDate = [dates lastObject ];
	ShortDate *refFromDate;
	ShortDate *refToDate;
	
	switch (histType) {
		case cat_histtype_year:
			refFromDate = [self.fromDate firstDayInYear ];
			refToDate = [self.toDate firstDayInYear ];
			break;
		case cat_histtype_quarter:
			refFromDate = [self.fromDate firstDayInQuarter ];
			refToDate = [self.toDate firstDayInQuarter ];
			break;
		default:
			refFromDate = self.fromDate;
			refToDate = self.toDate;
			break;
	}
	
	if ([fromDate compare:firstDate ] == NSOrderedAscending || [fromDate compare:lastDate ] == NSOrderedDescending) {
		self.fromDate = firstDate;
		[fromButton selectItemAtIndex:[dates count ] - 1 ];
	} else {
		int idx = [dates count ] - 1;
		for(ShortDate *date in dates) {
			if ([date isEqual:refFromDate ]) {
				[fromButton selectItemAtIndex:idx ];
			} else idx--;
		}
	}
	
	if ([toDate compare: lastDate ] == NSOrderedDescending || [toDate compare:firstDate ] == NSOrderedAscending) {
		self.toDate = lastDate;
		[toButton selectItemAtIndex:0 ];
	} else {
		int idx = [dates count ] - 1;
		for(ShortDate *date in dates) {
			if ([date isEqual:refToDate ]) {
				[toButton selectItemAtIndex:idx ];
			} else idx--;
		}
	}
}

-(NSView*)mainView
{
	return mainView;
}

-(IBAction) histTypeChanged: (id)sender
{
	NSSegmentedControl *sc = (NSSegmentedControl*)sender;
	int idx = [sc selectedSegment ];
	switch (idx) {
		case 0: histType = cat_histtype_year;
			[fromButton bind:@"contentValues" toObject:catPeriodDatesController withKeyPath:@"arrangedObjects.yearDescription" options: nil ];
			[toButton bind:@"contentValues" toObject:catPeriodDatesController withKeyPath:@"arrangedObjects.yearDescription" options: nil ];
			break;
		case 1: histType = cat_histtype_quarter; 
			[fromButton bind:@"contentValues" toObject:catPeriodDatesController withKeyPath:@"arrangedObjects.quarterYearDescription" options: nil ];
			[toButton bind:@"contentValues" toObject:catPeriodDatesController withKeyPath:@"arrangedObjects.quarterYearDescription" options: nil ];
			break;
		default: histType = cat_histtype_month; 
			[fromButton bind:@"contentValues" toObject:catPeriodDatesController withKeyPath:@"arrangedObjects.monthYearDescription" options: nil ];
			[toButton bind:@"contentValues" toObject:catPeriodDatesController withKeyPath:@"arrangedObjects.monthYearDescription" options: nil ];
			break;
	}
	self.fromDate = [self periodRefDateForDate: self.fromDate ];
	self.toDate = [self periodRefDateForDate: self.toDate ];
	[self updatePeriodDates ];
	[self adjustDates ];
	[self updateData ];
}

-(IBAction)fromButtonPressed:(id)sender
{
	int idx_from = [fromButton indexOfSelectedItem ];
	int idx_to = [toButton indexOfSelectedItem ];
	if (idx_from >=0 ) {
		self.fromDate = [[catPeriodDatesController arrangedObjects ] objectAtIndex:idx_from ];
	}
	if (idx_from < idx_to) {
		[toButton selectItemAtIndex:idx_from ];
		self.toDate = self.fromDate;
	}
	[self updateData ];
}

-(IBAction)toButtonPressed:(id)sender
{
	int idx_from = [fromButton indexOfSelectedItem ];
	int idx_to = [toButton indexOfSelectedItem ];
	if (idx_to >=0 ) {
		self.toDate = [[catPeriodDatesController arrangedObjects ] objectAtIndex:idx_to ];
	}
	if (idx_from < idx_to) {
		[fromButton selectItemAtIndex:idx_to ];
		self.fromDate = self.toDate;
	}
	[self updateData ];
}
		 
- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if(![[tableColumn identifier ] isEqualToString: @"category" ]) return;
	CategoryReportingNode *node = (CategoryReportingNode*)[item representedObject ];
		
	if([outlineView parentForItem:item ] == nil) {
		NSColor *txtColor;
		if([cell isHighlighted ]) txtColor = [NSColor whiteColor]; 
		else txtColor = [NSColor colorWithCalibratedHue: 0.6194 saturation: 0.32 brightness:0.56 alpha:1.0 ];
		NSFont *txtFont = [NSFont fontWithName: @"Arial Rounded MT Bold" size: 13];
		NSDictionary *txtDict = [NSDictionary dictionaryWithObjectsAndKeys: txtFont,NSFontAttributeName,txtColor, NSForegroundColorAttributeName, nil];
		NSAttributedString *attrStr = [[[NSAttributedString alloc] initWithString: [node name ] attributes:txtDict] autorelease];
		[cell setAttributedStringValue:attrStr];
	}
}

- (id)outlineView:(NSOutlineView *)outlineView persistentObjectForItem:(id)item 
{
    return [[item representedObject ] name ];
}

-(void)prepare
{
}

-(void)print
{
	NSPrintInfo	*printInfo = [NSPrintInfo sharedPrintInfo ];
	[printInfo setTopMargin:45 ];
	[printInfo setBottomMargin:45 ];
	[printInfo setHorizontalPagination:NSFitPagination ];
	[printInfo setVerticalPagination:NSAutoPagination ];
	NSPrintOperation *printOp;
	printOp = [NSPrintOperation printOperationWithView:printView printInfo: printInfo ];
	[printOp setShowsPrintPanel:YES ];
	[printOp runOperation ];	
}

-(void)terminate
{
	[categoryView saveLayout ];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults ];
	NSMutableDictionary *values = [NSMutableDictionary dictionaryWithCapacity:5 ];
	
	[values setObject:[NSNumber numberWithInt:histType ] forKey:@"type" ];
	[values setObject:[fromDate lowDate ] forKey:@"fromDate" ];
	[values setObject:[toDate highDate ] forKey:@"toDate" ];
	
	[userDefaults setObject:values forKey:@"catPeriodDefaults" ];
}


- (void)dealloc
{
	[categoryHistory release], categoryHistory = nil;
	[dates release], dates = nil;
	[selectedDates release], selectedDates = nil;
	[fromDate release], fromDate = nil;
	[toDate release], toDate = nil;
	[dataRoot release ], dataRoot = nil;
	[periodRoot release ], periodRoot = nil;
	[minDate release], minDate = nil;
	[maxDate release], maxDate = nil;
	[formatter release ], formatter = nil;
	[super dealloc];
}

@end

