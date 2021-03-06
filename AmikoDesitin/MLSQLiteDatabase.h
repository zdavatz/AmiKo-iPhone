/*
 
 Copyright (c) 2013 Max Lungarella <cybrmx@gmail.com>
 
 Created on 11/08/2013.
 
 This file is part of AmiKoDesitin.
 
 AmiKoDesitin is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
 
 ------------------------------------------------------------------------ */

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@interface MLSQLiteDatabase : NSObject

+ (void) createEditableCopyOfDatabaseIfNeeded: (NSString *)dbName;

- (id) initReadOnlyWithPath:(NSString *)path;
- (id) initWithPath: (NSString *)path;
- (NSArray *) performQuery: (NSString *)query;
- (NSInteger) numberRecordsForTable: (NSString *)table;
- (BOOL) insertRowIntoTable:(NSString *)table forColumns:(NSString *)columns andValues:(NSString *)values;
- (BOOL) updateRowIntoTable:(NSString *)table forExpressions:(NSString *)expressions andConditions:(NSString *)conditions;
- (BOOL) deleteRowFromTable:(NSString *)table withRowId:(long)rowId;
- (BOOL) deleteRowFromTable:(NSString *)table withUId:(NSString *)uId;
- (void) close;

- (BOOL) createWithPath:(NSString *)path andTable:(NSString *)table andColumns:(NSString *)columns
;
@end
