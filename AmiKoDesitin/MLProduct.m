//
//  MLProduct.m
//  AmikoDesitin
//
//  Created by Alex Bettarini on 1/29/18.
//  Copyright © 2018 Ywesee GmbH. All rights reserved.
//

#import "MLProduct.h"

@implementation MLProduct

@synthesize eanCode;
@synthesize packageInfo;
@synthesize prodName;
@synthesize comment;

@synthesize title, auth, regnrs, atccode;

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ ean:%@, regnrs:%@ <%@>",
            NSStringFromClass([self class]), self.eanCode, self.regnrs, self.title];
}

+ (id)importFromDict:(NSDictionary *)dict
{
    MLProduct *med = [[MLProduct alloc] init];
    
    med.eanCode     = [dict objectForKey:KEY_AMK_MED_EAN];
    med.packageInfo = [dict objectForKey:KEY_AMK_MED_PACKAGE];
    med.prodName    = [dict objectForKey:KEY_AMK_MED_PROD_NAME];
    med.comment     = [dict objectForKey:KEY_AMK_MED_COMMENT];
    
    med.title       = [dict objectForKey:KEY_AMK_MED_TITLE];
    med.auth        = [dict objectForKey:KEY_AMK_MED_OWNER];
    med.regnrs      = [dict objectForKey:KEY_AMK_MED_REGNRS];
    med.atccode     = [dict objectForKey:KEY_AMK_MED_ATC];
    
    return med;
}

#define INDEX_EAN_CODE_IN_PACK   9
- (id)initWithMedication:(MLMedication *)m :(NSInteger)packageIndex
{
#ifdef DEBUG
    NSLog(@"%s idx:%ld", __FUNCTION__, packageIndex);
#endif
    self = [super init];
    if (self) {
        NSArray *listOfPacks = [m.packages componentsSeparatedByString:@"\n"];
        //NSLog(@"listOfPacks:%@", listOfPacks);
        if (packageIndex < [listOfPacks count])
        {
            NSArray *p = [listOfPacks[packageIndex] componentsSeparatedByString:@"|"];
            //NSLog(@"%@", p);
            if ([p count] > INDEX_EAN_CODE_IN_PACK)
                self.eanCode = [p objectAtIndex:INDEX_EAN_CODE_IN_PACK];  // 2nd line in prescription view
        }
        
        NSArray *listOfPackInfos = [m.packInfo componentsSeparatedByString:@"\n"];
        //NSLog(@"listOfPackInfos:%@", listOfPackInfos);
        if (packageIndex < [listOfPackInfos count]) {
            self.packageInfo = listOfPackInfos[packageIndex]; // 1st line in prescription view
        }
        
        self.prodName = @"";    // TODO
        self.comment = @"";     // TODO

        self.title = m.title;
        self.auth = m.auth;
        self.regnrs = m.regnrs;
        self.atccode = m.atccode;
    }

    return self;
}

@end
