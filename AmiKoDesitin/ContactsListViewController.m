//
//  ContactsListViewController.m
//  AmikoDesitin
//
//  Created by Alex Bettarini on 8 Feb 2018
//  Copyright © 2018 Ywesee GmbH. All rights reserved.
//

#import "ContactsListViewController.h"
#import <Contacts/Contacts.h>
#import "Patient.h"
#import "SWRevealViewController.h"

@interface ContactsListViewController ()
{
    UIColor *textColor;
    NSString *tableIdentifier;
    NSNotificationName notificationName;
}

- (BOOL) stringIsNilOrEmpty:(NSString*)str;

@end

@implementation ContactsListViewController
{
    NSMutableArray *mFilteredArrayOfPatients;
    NSString *mPatientUUID;
    BOOL mSearchFiltered;

    NSArray *mArrayOfPatients;
    NSMutableArray *groupOfContacts;
}

@synthesize theSearchBar;

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    notificationName = @"ContactSelectedNotification";
    tableIdentifier = @"contactsListTableItem";
    textColor = [UIColor grayColor];
    
    mFilteredArrayOfPatients = [NSMutableArray new];
    mSearchFiltered = FALSE;
    mPatientUUID = nil;
    
    // Retrieves contacts from address book
    mArrayOfPatients = [self getAllContacts];
#ifdef DEBUG
//    NSLog(@"%s mArrayOfPatients count:%ld", __FUNCTION__, [mArrayOfPatients count]);
//    for (Patient *p in mArrayOfPatients)
//        NSLog(@"%s familyName: %@", __FUNCTION__, p.familyName);
#endif
}

- (void)viewDidAppear:(BOOL)animated {
    [self.theSearchBar becomeFirstResponder];
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

#pragma mark -

- (Patient *) getContactAtRow:(NSInteger)row
{
    if (mSearchFiltered)
        return mFilteredArrayOfPatients[row];

    if (mArrayOfPatients)
        return mArrayOfPatients[row];

    return nil;
}

#pragma mark - MLContact

- (NSArray *) getAllContacts
{
    groupOfContacts = [@[] mutableCopy];
    [self addAllContactsToArray:groupOfContacts];
    return groupOfContacts;
}

- (NSArray *) addAllContactsToArray:(NSMutableArray *)arrayOfContacts
{
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    if (status == CNAuthorizationStatusDenied) {
        NSLog(@"This app was refused permissions to contacts.");
    }
    
    if ([CNContactStore class]) {
        CNContactStore *addressBook = [CNContactStore new];
        
        NSArray *keys = @[CNContactIdentifierKey,
                          CNContactFamilyNameKey,
                          CNContactGivenNameKey,
                          CNContactBirthdayKey,
                          CNContactPostalAddressesKey,
                          CNContactPhoneNumbersKey,
                          CNContactEmailAddressesKey];
        
        CNContactFetchRequest *request = [[CNContactFetchRequest alloc] initWithKeysToFetch:keys];
        
        NSError *error;
        [addressBook enumerateContactsWithFetchRequest:request
                                                 error:&error
                                            usingBlock:^(CNContact * __nonnull contact, BOOL * __nonnull stop) {
                                                if (error) {
                                                    NSLog(@"error fetching contacts %@", error);
                                                }
                                                else {
                                                    Patient *patient = [Patient new];
                                                    patient.familyName = contact.familyName;
                                                    patient.givenName = contact.givenName;
                                                    // Postal address
                                                    patient.postalAddress = @"";
                                                    patient.zipCode = @"";
                                                    patient.city = @"";
                                                    patient.country = @"";
                                                    if ([contact.postalAddresses count]>0) {
                                                        CNPostalAddress *pa = [contact.postalAddresses[0] value];
                                                        patient.postalAddress = pa.street;
                                                        patient.zipCode = pa.postalCode;
                                                        patient.city = pa.city;
                                                        patient.country = pa.country;
                                                    }
                                                    // Email address
                                                    patient.emailAddress = @"";
                                                    if ([contact.emailAddresses count]>0)
                                                        patient.emailAddress = [contact.emailAddresses[0] value];
                                                    // Birthdate
                                                    patient.birthDate = @"";
                                                    if (contact.birthday.year>1900)
                                                        patient.birthDate = [NSString stringWithFormat:@"%ld-%ld-%ld", contact.birthday.day, contact.birthday.month, contact.birthday.year];
                                                    // Phone number
                                                    patient.phoneNumber = @"";
                                                    if ([contact.phoneNumbers count]>0)
                                                        patient.phoneNumber = [[contact.phoneNumbers[0] value] stringValue];
                                                    // Add only if patients names are meaningful
                                                    if ([patient.familyName length]>0 && [patient.givenName length]>0) {
                                                        //patient.databaseType = eAddressBook; // TODO
                                                        [arrayOfContacts addObject:patient];
                                                    }
                                                }
                                            }];
        // Sort alphabetically
        if ([arrayOfContacts count]>0) {
            NSSortDescriptor *nameSort = [NSSortDescriptor sortDescriptorWithKey:@"familyName" ascending:YES];
            [arrayOfContacts sortUsingDescriptors:[NSArray arrayWithObject:nameSort]];
        }
    }
    
    return arrayOfContacts;
}

- (BOOL) stringIsNilOrEmpty:(NSString*)str
{
    return !(str && str.length);
}

#pragma mark - UISearchBarDelegate

// See onSearchDatabase in AmiKo-macOS
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [mFilteredArrayOfPatients removeAllObjects];
    if (![self stringIsNilOrEmpty:searchText]) {
        NSPredicate *p1 = [NSPredicate predicateWithFormat:@"familyName BEGINSWITH[cd] %@", searchText];
        NSPredicate *p2 = [NSPredicate predicateWithFormat:@"givenName BEGINSWITH[cd] %@", searchText];
        NSPredicate *p3 = [NSPredicate predicateWithFormat:@"postalAddress BEGINSWITH[cd] %@", searchText];
        NSPredicate *p4 = [NSPredicate predicateWithFormat:@"zipCode BEGINSWITH[cd] %@", searchText];
        
        NSPredicate *predicate = [NSCompoundPredicate orPredicateWithSubpredicates: [NSArray arrayWithObjects: p1, p2, p3, p4, nil]];
        
        mFilteredArrayOfPatients = [[mArrayOfPatients filteredArrayUsingPredicate:predicate] mutableCopy];
    }
    
    if (mFilteredArrayOfPatients) {
        if ([mFilteredArrayOfPatients count]>0) {
            //[self setNumPatients:[mFilteredArrayOfPatients count]];  // TODO
            mSearchFiltered = TRUE;
        }
        else {
            if ([searchText length]>0) {
                //[self setNumPatients:0]; // TODO
                mSearchFiltered = TRUE;
            }
            else {
                //[self setNumPatients:[mArrayOfPatients count]]; // TODO
                mSearchFiltered = FALSE;
            }
        }
    }
    else {
        // [self setNumPatients:[mArrayOfPatients count]]; // TODO
        mSearchFiltered = FALSE;
    }
    
    [mTableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger) tableView: (UITableView *)tableView
  numberOfRowsInSection: (NSInteger)section
{
    if (mSearchFiltered)
        return [mFilteredArrayOfPatients count];

    return [mArrayOfPatients count];
}

- (UITableViewCell *) tableView: (UITableView *)tableView
          cellForRowAtIndexPath: (NSIndexPath *)indexPath
{
    //static NSString *tableIdentifier = @"contactsListTableItem";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:tableIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:tableIdentifier];
        cell.textLabel.textAlignment = NSTextAlignmentRight;
        //cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.textColor = textColor;
    }
    
    Patient *p = [self getContactAtRow:indexPath.row];
    NSString *cellStr = [NSString stringWithFormat:@"%@ %@", p.familyName, p.givenName];
    cell.textLabel.text = cellStr;
    //cell.detailTextLabel.text = [NSString stringWithFormat:@"example %ld", indexPath.row];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void) tableView: (UITableView *)tableView didSelectRowAtIndexPath: (NSIndexPath *)indexPath
{
#ifdef DEBUG
    NSLog(@"%s selected row:%ld", __FUNCTION__, indexPath.row);
#endif
    
    Patient *p = [self getContactAtRow:indexPath.row];
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName
                                                        object:p];
    mPatientUUID = p.uniqueId;
    mSearchFiltered = FALSE;
}

@end
