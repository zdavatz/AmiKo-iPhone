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

#import "MLSecondViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "MLConstants.h"
#import "SWRevealViewController.h"
#import "MLSearchWebView.h"
#import "MLMedication.h"
//#import "MLMenuViewController.h"
#import "MLViewController.h"

#import "MLAlertView.h"

#import "WebViewJavascriptBridge.h"
#import "MLUtility.h"

typedef NS_ENUM(NSInteger, FindPanelVisibility) {
    FIND_PANEL_INVISIBLE,
    FIND_PANEL_VISIBLE,
    FIND_PANEL_UNDEFINED
};

#pragma mark - Class extension
////////////////////////////////////////////////////////////////////////////////
@interface MLSecondViewController ()
@property WebViewJavascriptBridge *jsBridge;
@end

#pragma mark -
////////////////////////////////////////////////////////////////////////////////
@implementation MLSecondViewController
{
    int mNumRevealButtons;
    int mTotalHighlightCount;
    int mCurrentHightlightIndex;
#ifdef WITH_ANIMATION
    float frameY_Visible;
    float frameY_Invisible;
#endif
    FindPanelVisibility wasVisible;
    NSString *mTitle;
    NSString *mCurrentSearch;
}

@synthesize webView;
@synthesize searchBarView, searchField;
@synthesize findPanel, findCounter;
@synthesize htmlStr;
@synthesize medBasket;
@synthesize titleViewController;
//@synthesize anchor;
@synthesize keyword;

- (void) dealloc
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif

    htmlAnchor = nil;
    htmlStr = nil;
    medBasket = nil;
    
    self.webView.UIDelegate = nil;
    self.webView = nil;
    [self.webView removeFromSuperview];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype) initWithNibName:(NSString *)nibNameOrNil
                          bundle:(NSBundle *)nibBundleOrNil
                           title:(NSString *)title
                        andParam:(int)numRevealButtons
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    self = [self initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    mCurrentSearch = @"";
    [self resetSearchField];
    
    mNumRevealButtons = numRevealButtons;
    mTitle = title;
    
    wasVisible = FIND_PANEL_UNDEFINED;
    
    return self;
}

// It doesn't seem to get called
- (instancetype) initWithNibName: (NSString *)nibNameOrNil
                          bundle: (NSBundle *)nibBundleOrNil
                      withString: (NSString *)html
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    self = [super init];

    mCurrentSearch = @"";
    [self resetSearchField];

    htmlStr = [[NSString alloc] initWithString:html];
    
    return self;
}

#pragma mark - IBAction methods

- (IBAction) moveToPrevHighlight:(id)sender
{
    if (mTotalHighlightCount <= 1)
        return;

    mCurrentHightlightIndex--;
    if (mCurrentHightlightIndex < 0)
        mCurrentHightlightIndex = mTotalHighlightCount-1;

#ifdef DEBUG
    NSLog(@"%s line %d, highlight index: %d of %d", __FUNCTION__, __LINE__,
          mCurrentHightlightIndex, mTotalHighlightCount);
#endif

    [self.webView nextHighlight:(mTotalHighlightCount-mCurrentHightlightIndex-1)];
    [self updateFindCounterLabel];
}

- (IBAction) moveToNextHighlight:(id)sender
{
    if (mTotalHighlightCount <= 1) {
        // TODO: make sure findPanel is hidden
        return;
    }

    mCurrentHightlightIndex++;
    if (mCurrentHightlightIndex >= mTotalHighlightCount)
        mCurrentHightlightIndex = 0;

#ifdef DEBUG
    NSLog(@"%s line %d, highlight: %d of %d", __FUNCTION__, __LINE__, mCurrentHightlightIndex, mTotalHighlightCount);
#endif

    [self.webView nextHighlight:(mTotalHighlightCount-mCurrentHightlightIndex-1)];
    [self updateFindCounterLabel];
}

- (void) resetSearchField
{
#ifdef DEBUG
    NSLog(@"%s line %d, mCurrentSearch: <%@>", __FUNCTION__, __LINE__, mCurrentSearch);
#endif
    if ([mCurrentSearch length] > 0)
        [searchField setText:mCurrentSearch];
    else {
        [searchField setText:@""];
        // Note: 'keyword' must be preserved, don't clear it here
    }
    
    if ([self.htmlStr isEqualToString:@"Interactions"])
        [searchField setPlaceholder:[NSString stringWithFormat:NSLocalizedString(@"Search in interactions", nil)]];
    else
        [searchField setPlaceholder:[NSString stringWithFormat:NSLocalizedString(@"Search in technical info", nil)]];
    
    if ([mTitle isEqualToString:@"About"])
        [searchField setPlaceholder:NSLocalizedString(@"Search in report", nil)];
}

- (void) updateFindCounterLabel
{
    if (mTotalHighlightCount <= 0) {
        [self.findCounter setText:@""];
        return;
    }

#ifdef DEBUG
    //NSLog(@"%s %d, highlight index %d of %d", __FUNCTION__, __LINE__, mCurrentHightlightIndex, mTotalHighlightCount);
#endif

    [self.findCounter setText:[NSString stringWithFormat:@"%d/%d",
                               mCurrentHightlightIndex+1, mTotalHighlightCount]];
}

/**
 This is the observing class
 */
- (void) observeValueForKeyPath:(NSString *)keyPath
                       ofObject:(id)object
                         change:(NSDictionary *)change
                        context:(void *)context
{
#ifdef DEBUG
    NSLog(@"%s line %d, keyPath: %@, change:%@", __FUNCTION__, __LINE__, keyPath, change);
#endif
    // [self addObserver:self forKeyPath:@"javaScript" options:0 context:@"javaScriptChanged"];
    // This class is added as an observer in '[MLViewController switchToAipsView]'
    if ([keyPath isEqualToString:@"javaScript"]) {
        htmlAnchor = [NSString stringWithString:[change objectForKey:@"new"]];
        [self.webView stopLoading];
        [self.webView evaluateJavaScript:htmlAnchor
                       completionHandler:^(NSString* result, NSError *error) {
            if (error)
                NSLog(@"%s line %d, %@", __FUNCTION__, __LINE__, error.localizedDescription);
        }];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -

- (void) viewWillAppear:(BOOL)animated
{
#ifdef DEBUG
    NSLog(@"%s, htmlStr length: %lu", __FUNCTION__, (unsigned long)[htmlStr length]);
#endif
    
    [super viewWillAppear:animated];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        if (orientation == UIInterfaceOrientationLandscapeLeft ||
            orientation == UIInterfaceOrientationLandscapeRight)
        {
            self.revealViewController.rearViewRevealWidth = RearViewRevealWidth_Landscape_iPad;
        }
        else {
            self.revealViewController.rearViewRevealWidth = RearViewRevealWidth_Portrait_iPad;
        }

        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    else if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {

        if (orientation == UIInterfaceOrientationLandscapeLeft ||
            orientation == UIInterfaceOrientationLandscapeRight)
        {
            self.revealViewController.rearViewRevealWidth = [MLConstants rearViewRevealWidthLandscape];

            [[UIApplication sharedApplication] setStatusBarHidden:YES
                                                    withAnimation:UIStatusBarAnimationSlide];
        }
        else {
            self.revealViewController.rearViewRevealWidth = [MLConstants rearViewRevealWidthPortrait];
            self.revealViewController.rearViewRevealOverdraw = [MLConstants rearViewRevealOverdrawPortrait];
        }

        [self updateFindCounterLabel];
        self.navigationItem.titleView = searchBarView;
        self.edgesForExtendedLayout = UIRectEdgeNone;
    } // iPhone
    
#ifdef WITH_ANIMATION
    frameY_Visible = findPanel.frame.origin.y;
    frameY_Invisible = findPanel.frame.origin.y - 200;
#endif
    self.findPanel.layer.cornerRadius = 6.0f;
    wasVisible = FIND_PANEL_UNDEFINED;
    [self showFindPanel:FIND_PANEL_INVISIBLE]; // position it off screen

    mCurrentSearch = @"";
    // Reset search field place holder
    [self resetSearchField];
    
    // Update webview which is either "Fachinfo" or "medication basket"
    [self updateWebView];

    [self createJSBridge];
}

- (void) viewDidAppear:(BOOL)animated
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
//    for (id gr in self.view.gestureRecognizers)
//        NSLog(@"gestureRecognizer: %@", [gr class]);
#endif
    
    [super viewDidAppear:animated];
    
    [self.webView reload];
    
    if ([keyword length] > 0)
        [self.searchField setText:keyword];
}

- (void) viewDidLoad
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
//    for (id gr in self.view.gestureRecognizers)
//        NSLog(@"gestureRecognizer: %@", [gr class]);
#endif
    
    [super viewDidLoad];
    
    // Do any additional setup after loading the view from its nib.
    self.title = mTitle;
    self.webView.UIDelegate = self;

    // SWRevealViewController extends UIViewController!
    SWRevealViewController *revealController = [self revealViewController];
    
    [self.navigationController.navigationBar addGestureRecognizer:revealController.panGestureRecognizer];
    
#if 0 // @@@
    self.navigationController.navigationBar.backgroundColor = VERY_LIGHT_GRAY_COLOR;// MAIN_TINT_COLOR;
    self.navigationController.navigationBar.barTintColor = VERY_LIGHT_GRAY_COLOR;
#endif
    self.navigationController.navigationBar.translucent = NO;
    
    {
        UIBarButtonItem *revealButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:NAVIGATION_ICON_LEFT]
                                         style:UIBarButtonItemStylePlain
                                        target:revealController
                                        action:@selector(revealToggle:)];
        self.navigationItem.leftBarButtonItem = revealButtonItem;
    }
    
    if ( mNumRevealButtons == 2 )
    {
        UIBarButtonItem *rightRevealButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:NAVIGATION_ICON_RIGHT]
                                         style:UIBarButtonItemStylePlain
                                        target:revealController
                                        action:@selector(rightRevealToggle:)];
        self.navigationItem.rightBarButtonItem = rightRevealButtonItem;
    }
    
    // PanGestureRecognizer goes here ... could be also placed in the other Views but this is the main view!
    // [self.navigationController.navigationBar addGestureRecognizer:revealController.panGestureRecognizer];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        searchField.translucent = YES;
    }
    else if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        //self.navigationItem.titleView = searchBarView;
    }
    
    [self.view addGestureRecognizer:revealController.panGestureRecognizer];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        UIGestureRecognizer *tapper = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(handleSingleTap:)];
        tapper.cancelsTouchesInView = NO;
        [self.view addGestureRecognizer:tapper];
    }
}

- (void) didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
 
    NSLog(@"%s", __FUNCTION__);
    // Dispose of any resources that can be recreated.
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

#pragma mark -

/**
 Removes keyboard on iPhones
 */
- (void) handleSingleTap:(UITapGestureRecognizer *)sender
{
    [searchField resignFirstResponder];
}

//- (void) viewDidUnload
//{
//    self.webView = nil;
//}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

// TODO: Implement 'viewWillTransitionToSize:withTransitionCoordinator:' instead
- (void) willRotateToInterfaceOrientation: (UIInterfaceOrientation)toInterfaceOrientation
                                 duration: (NSTimeInterval)duration
{
#ifdef DEBUG
    //NSLog(@"%s %d, next orientation: %ld", __FUNCTION__, __LINE__, (long)toInterfaceOrientation);
#endif
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
            toInterfaceOrientation == UIInterfaceOrientationLandscapeRight)
            self.revealViewController.rearViewRevealWidth = RearViewRevealWidth_Landscape_iPad;
        else
            self.revealViewController.rearViewRevealWidth = RearViewRevealWidth_Portrait_iPad;
        
        searchField.translucent = YES;
    }
    else if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {

        //[self updateFindCounterLabel];  // the count didn't change just by changing orientation

        if (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
            toInterfaceOrientation == UIInterfaceOrientationLandscapeRight)
        {
            self.revealViewController.rearViewRevealWidth = [MLConstants rearViewRevealWidthLandscape];
            self.revealViewController.rearViewRevealOverdraw = [MLConstants rearViewRevealOverdrawLandscape];

            [[UIApplication sharedApplication] setStatusBarHidden:YES
                                                    withAnimation:UIStatusBarAnimationSlide];
        }
        else {
            self.revealViewController.rearViewRevealWidth = [MLConstants rearViewRevealWidthPortrait];

            // Shows status bar
            [[UIApplication sharedApplication] setStatusBarHidden:NO
                                                    withAnimation:UIStatusBarAnimationSlide];
        }
    }

    [self resetSearchField];
}

/**
 The following function intercepts messages sent from javascript to objective C and acts
 acts as a bridge between JS and ObjC
 */
- (void) createJSBridge
{
    if (_jsBridge)
        return;
    
#ifdef DEBUG
    NSLog(@"%s", __PRETTY_FUNCTION__);
#endif
    [WebViewJavascriptBridge enableLogging];

    _jsBridge = [WebViewJavascriptBridge bridgeForWebView: webView];
    [_jsBridge setWebViewDelegate:self];
    [_jsBridge registerHandler:@"JSToObjC_"
                       handler:^(id msg, WVJBResponseCallback responseCallback) {
        if ([msg isEqualToString:@"notify_interaction"]) {
#ifdef DEBUG
            NSLog(@"%s line %d, Notify interaction", __FUNCTION__, __LINE__);
#endif
            [self sendEmailTo:@"zdavatz@ywesee.com"
                  withSubject:[NSString stringWithFormat:@"%@: Unbekannte Interaktionen", APP_NAME]];
        }
        else if ([msg isEqualToString:@"delete_all"]) {
#ifdef DEBUG
            NSLog(@"%s line %d, Delete all", __FUNCTION__, __LINE__);
#endif
            [self.medBasket removeAllObjects];
            [self updateInteractionBasketView];
        }
        else {
#ifdef DEBUG
            NSLog(@"%s line %d, Delete number %@", __FUNCTION__, __LINE__, msg);
#endif
            [self.medBasket removeObjectForKey:msg];
            [self updateInteractionBasketView];
        }
    }];
}

- (void) sendEmailTo:(NSString *)recipient withSubject:(NSString *)subject
{
    // Check if device is configured to send email
    if ([MFMailComposeViewController canSendMail]) {
        // Init mail view controller
        MFMailComposeViewController *mailer = [MFMailComposeViewController new];
        mailer.mailComposeDelegate = self;
        
        // Subject
        [mailer setSubject:subject];
        // Recipient
        if (![recipient isEqualToString:@""]) {
            NSArray *toRecipients = [NSArray arrayWithObjects:recipient, nil];
            [mailer setToRecipients:toRecipients];
        }
        // Attach screenshot...
        // UIImage *screenShot = [UIImage imageNamed:@"Default.png"];
        UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, NO, [UIScreen mainScreen].scale);
        [self.view drawViewHierarchyInRect:self.view.bounds afterScreenUpdates:YES];
        UIImage *screenShot = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        NSData *imageData = UIImagePNGRepresentation(screenShot);
        
        [mailer addAttachmentData:imageData mimeType:@"image/png" fileName:@"Images"];

        // It's important to use the presenting root view controller...
        UIViewController *presentingController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
        [presentingController presentViewController:mailer animated:YES completion:nil];
    }
    else {
        MLAlertView *alert = [[MLAlertView alloc] initWithTitle:@"Failure"
                                                        message:@"Your device is not configured to send emails."
                                                         button:@"OK"];
        [alert show];
    }
}

// Updates medication basket HTML string
// See 'fullInteractionsHtml' in AmiKo-macOS
- (void) updateInteractionBasketView
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    // TODO: Optimize: pre-load the following files
    
    NSString *color_Style =
        [NSString stringWithFormat:@"<style type=\"text/css\">%@</style>", [MLUtility getColorCss]];

    NSString *interactions_Style;
    {
        // Load style sheet from file
        NSString *interactionsCssPath = [[NSBundle mainBundle] pathForResource:@"interactions_css" ofType:@"css"];
        NSString *interactionsCss = [NSString stringWithContentsOfFile:interactionsCssPath encoding:NSUTF8StringEncoding error:nil];
        interactions_Style = [NSString stringWithFormat:@"<style type=\"text/css\">%@</style>", interactionsCss];
    }
    
    // Load JavaScript from file
    NSString *js_Script;
    {
        NSString *jscriptPath = [[NSBundle mainBundle] pathForResource:@"deleterow" ofType:@"js"];
        NSString *jscriptStr = [NSString stringWithContentsOfFile:jscriptPath encoding:NSUTF8StringEncoding error:nil];
        js_Script = [NSString stringWithFormat:@"<script type=\"text/javascript\">%@</script>", jscriptStr];
    }
    
    NSString *charset_Meta = @"<meta charset=\"utf-8\" />";
    NSString *colorScheme_Meta= @"<meta name=\"supported-color-schemes\" content=\"light dark\" />";
    NSString *scaling_Meta = @"<meta name=\"viewport\" content=\"initial-scale=1.0\" />";

    // Generate main interaction table
    NSString *html_Head = [NSString stringWithFormat:@"<head>%@\n%@\n%@\n%@\n%@\n%@</head>",
            charset_Meta,
            colorScheme_Meta,
            scaling_Meta,
            js_Script,
            color_Style,
            interactions_Style];
    
    NSString *html_Body = [NSString stringWithFormat:@"<body><div id=\"interactions\">%@<br><br>%@<br>%@</div></body>",
            [self medBasketHtml],
            [self interactionsHtml],
            [self footNoteHtml]];
    
    self.htmlStr = [NSString stringWithFormat:@"<!DOCTYPE html><html>\n%@\n%@\n</html>", html_Head, html_Body];
    
#if 0 //def DEBUG
    // Create an HTML file of the Fachinfo, so it can be tested with Safari and inspected with an editor
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents directory
    NSError *error;
    NSString *path = [documentsDirectory stringByAppendingPathComponent:@"interactions.html"];
    BOOL succeed = [self.htmlStr writeToFile:path
                                  atomically:YES
                                    encoding:NSUTF8StringEncoding
                                       error:&error];
    if (succeed)
        NSLog(@"Created file: %@", path);
    else
        NSLog(@"%@", error.localizedDescription);
#endif

    [self updateWebView];
}

/** 
 Updates main webview in second viewcontroller
 */
- (void) updateWebView
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
    //NSLog(@"%s htmlStr:\n\n%@", __FUNCTION__, [htmlStr substringToIndex:MIN(500,[htmlStr length])]);
#endif
    
    if ([htmlStr length] == 0) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            // The iPad always shows part of this page on the right of the screen.
            // Without this workaround the initial empty page will stay white even in dark mode.
            // Ideally the WKWebkit should do this by itself. To be checked in future SDK releases.
            self.htmlStr = @"<html><head><meta name=\"supported-color-schemes\" content=\"light dark\" /></head><body></body></html>";
        }
        else
            return; // iPhone
    }
    else if ([htmlStr isEqualToString:@"Interactions"])
        [self updateInteractionBasketView];

    NSURL *mainBundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    // Loads HTML directly into webview
    [self.webView loadHTMLString:self.htmlStr
                         baseURL:mainBundleURL];
    /*
     [self.webView stopLoading];
     [self.webView reload];
     */
}

#pragma mark - medication basket methods

/** 
 Creates interaction basket HTML string
 */
- (NSString *) medBasketHtml
{
    // basket_html_str + delete_all_button_str + "<br><br>" + top_note_html_str
    int medCnt = 0;
    NSString *medBasketStr = [NSString stringWithFormat:
                              @"<div id=\"Medikamentenkorb\"><fieldset><legend>%@</legend></fieldset></div>"
                              @"<table id=\"InterTable\" width=\"100%%25\">",
                              NSLocalizedString(@"Drugs Basket", nil)];
    
    // Check if there are meds in the "Medikamentenkorb"
    if ([medBasket count]>0) {
        // First sort them alphabetically
        NSArray *sortedNames = [[medBasket allKeys] sortedArrayUsingSelector: @selector(compare:)];
        // Loop through all meds
        for (NSString *name in sortedNames) {
            MLMedication *med = [medBasket valueForKey:name];
            NSArray *m_code = [[med atccode] componentsSeparatedByString:@";"];
            NSString *atc_code = @"k.A.";
            NSString *active_ingredient = @"k.A";
            if ([m_code count]>1) {
                atc_code = [m_code objectAtIndex:0];
                active_ingredient = [m_code objectAtIndex:1];
            }
            // Increment med counter
            medCnt++;
            // Update medication basket
            medBasketStr = [medBasketStr stringByAppendingFormat:@"<tr>"
                            @"<td>%d</td>"
                            @"<td>%@</td>"
                            @"<td>%@</td>"
                            @"<td>%@</td>"
                            @"<td align=\"right\"><input type=\"image\" src=\"217-trash.png\" onclick=\"deleteRow('Single','InterTable',this)\" />"
                            @"</tr>", medCnt, name, atc_code, active_ingredient];
        }

        // Add delete all button
        medBasketStr = [medBasketStr stringByAppendingFormat:@"</table>"
                        @"<div id=\"Delete_all\"><input type=\"button\" "
                        @"value=\"%@\" "
                        @"onclick=\"deleteRow('Delete_all','InterTable',this)\" /></div>",
                        NSLocalizedString(@"Delete everything", nil)];
    }
    else {
        medBasketStr = [NSString stringWithFormat:@"<div>%@<br><br></div>",
                        NSLocalizedString(@"Your medicine basket is empty", nil)];
    }
    
    return medBasketStr;
}

- (NSString *) topNoteHtml
{
    NSString *topNote = @"";
    
    if ([medBasket count]>1) {
        // Add note to indicate that there are no interactions
        topNote = [NSString stringWithFormat:
                   @"<fieldset><legend>%@</legend></fieldset>"
                   @"<p>%@</p>",
                   NSLocalizedString(@"Known interactions", nil),
                   NSLocalizedString(@"If no interactions are displayed, no interactions known", nil)];
    }
    
    return topNote;
}

/**
 Creates HTML displaying interactions between drugs
 */
- (NSString *) interactionsHtml
{  
    NSMutableString *interactionStr = [[NSMutableString alloc] initWithString:@""];
    NSMutableArray *sectionIds = [[NSMutableArray alloc] initWithObjects:@"Medikamentenkorb", nil];
    NSMutableArray *sectionTitles = nil;
    
    if ([medBasket count]>0)
        sectionTitles = [[NSMutableArray alloc] initWithObjects:NSLocalizedString(@"Drugs Basket", nil), nil];
    
    // Check if there are meds in the "Medikamentenkorb"
    if ([medBasket count] > 1) {
        [interactionStr appendString:[NSString stringWithFormat:
                                      @"<fieldset><legend>%@</legend></fieldset>",
                                      NSLocalizedString(@"Known interactions", nil)]];

        // First sort them alphabetically
        NSArray *sortedNames = [[medBasket allKeys] sortedArrayUsingSelector: @selector(compare:)];
        // Big loop
        for (NSString *name1 in sortedNames) {
            for (NSString *name2 in sortedNames) {
                if (![name1 isEqualToString:name2]) {
                    // Extract meds by names from interaction basket
                    MLMedication *med1 = [medBasket valueForKey:name1];
                    MLMedication *med2 = [medBasket valueForKey:name2];
                    // Get ATC codes from interaction db
                    NSArray *m_code1 = [[med1 atccode] componentsSeparatedByString:@";"];
                    NSArray *m_code2 = [[med2 atccode] componentsSeparatedByString:@";"];
                    NSArray *atc1 = nil;
                    NSArray *atc2 = nil;
                    if ([m_code1 count]>1)
                        atc1 = [[m_code1 objectAtIndex:0] componentsSeparatedByString:@","];
                    if ([m_code2 count]>1)
                        atc2 = [[m_code2 objectAtIndex:0] componentsSeparatedByString:@","];
                    
                    NSString *atc_code1 = @"";
                    NSString *atc_code2 = @"";
                    if (atc1!=nil && [atc1 count]>0) {
                        for (atc_code1 in atc1) {
                            if (atc2!=nil && [atc2 count]>0) {
                                for (atc_code2 in atc2) {
                                    NSString *html = [self.dbAdapter getInteractionHtmlBetween:atc_code1 and:atc_code2];
                                    if (html!=nil) {
                                        // Replace all occurrences of atc codes by med names apart from the FIRST one!
                                        NSRange range1 = [html rangeOfString:atc_code1 options:NSBackwardsSearch];
                                        html = [html stringByReplacingCharactersInRange:range1 withString:name1];
                                        NSRange range2 = [html rangeOfString:atc_code2 options:NSBackwardsSearch];
                                        html = [html stringByReplacingCharactersInRange:range2 withString:name2];
                                        // Concatenate strings
                                        [interactionStr appendString:html];
                                        // Add to title and anchor lists
                                        [sectionTitles addObject:[NSString stringWithFormat:@"%@ \u2192 %@", name1, name2]];
                                        [sectionIds addObject:[NSString stringWithFormat:@"%@-%@", atc_code1, atc_code2]];
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if ([sectionTitles count] < 2) {
            NSString *note = NSLocalizedString(@"Currently, there are no interactions between these drugs in the EPha.ch database. For more information, please refer to the technical information.", nil);

            NSString *button = [NSString stringWithFormat:@"<input type=\"button\" value=\"%@\" onclick=\"deleteRow('Notify_interaction','InterTable',this)\" />", NSLocalizedString(@"Report an interaction", nil)];

            NSString *noInteractions_Par_Div = [NSString stringWithFormat:@"<p class=\"paragraph0\">%@</p><div id=\"Delete_all\">%@</div><br>", note, button];

            [interactionStr appendString:noInteractions_Par_Div];
        }
        else if ([sectionTitles count] > 2) {
            [interactionStr appendString:@"<br>"];
        }
    }
    
    if ([medBasket count] > 0) {
        [sectionIds addObject:@"Farblegende"]; // TODO: Can we localize this ?
        [sectionTitles addObject:NSLocalizedString(@"Color Legend", "Interactions")];
    }
    
    if (titleViewController)
        [titleViewController setSectionTitles:[NSArray arrayWithArray:sectionTitles]
                                       andIds:[NSArray arrayWithArray:sectionIds]];
    
    return interactionStr;
}

- (NSString *) footNoteHtml
{
    /*
     Risikoklassen
     -------------
     A: Keine Massnahmen notwendig (grün)
     B: Vorsichtsmassnahmen empfohlen (gelb)
     C: Regelmässige Überwachung (orange)
     D: Kombination vermeiden (pinky)
     X: Kontraindiziert (hellrot)
     0: Keine Angaben (grau)
     */
    if ([medBasket count] == 0)
            return @"";

    NSString *fieldset = [NSString stringWithFormat:@"<fieldset><legend>%@</legend></fieldset>", NSLocalizedString(@"Footnotes", "Interactions")];
    NSString *footnote1_par = [NSString stringWithFormat:@"<p class=\"footnote\">1. %@:</p>", NSLocalizedString(@"Color Legend", "Interactions")];
    NSString *footnote2_par = [NSString stringWithFormat:@"<p class=\"footnote\">2. %@.</p>", NSLocalizedString(@"Data source: Public domain data from EPha.ch", "Interactions")];
    NSString *footnote3_par = [NSString stringWithFormat:@"<p class=\"footnote\">3. %@.</p>", NSLocalizedString(@"Supported by: IBSA Institut Biochimique SA", "Interactions")];

    NSString *colorA_tr = [NSString stringWithFormat:@"<tr bgcolor=\"#caff70\"><td align=\"center\">A</td><td>%@</td></tr>", NSLocalizedString(@"No measures necessary", "Interactions")];
    NSString *colorB_tr = [NSString stringWithFormat:@"<tr bgcolor=\"#ffec8b\"><td align=\"center\">B</td><td>%@</td></tr>", NSLocalizedString(@"Precautionary measures recommended", "Interactions")];
    NSString *colorC_tr = [NSString stringWithFormat:@"<tr bgcolor=\"#ffb90f\"><td align=\"center\">C</td><td>%@</td></tr>", NSLocalizedString(@"Regular monitoring", "Interactions")];
    NSString *colorD_tr = [NSString stringWithFormat:@"<tr bgcolor=\"#ff82ab\"><td align=\"center\">D</td><td>%@</td></tr>", NSLocalizedString(@"Avoid combination", "Interactions")];
    NSString *colorX_tr = [NSString stringWithFormat:@"<tr bgcolor=\"#ff6a6a\"><td align=\"center\">X</td><td>%@</td></tr>", NSLocalizedString(@"Contraindicated", "Interactions")];
    NSString *table = [NSString stringWithFormat:@"<table id=\"Farblegende\" style=\"background-color:transparent;\" cellpadding=\"3px\" width=\"100%%25\">\n %@\n %@\n %@\n %@\n %@\n</table>", colorA_tr, colorB_tr, colorC_tr, colorD_tr, colorX_tr];

    NSString *legend = [NSString stringWithFormat:@"%@\n %@\n %@\n %@\n %@\n",
                         fieldset, footnote1_par, table, footnote2_par, footnote3_par];

    return legend;
}

#pragma mark - UISearchBarDelegate methods

- (void) searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
}

- (void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
#ifdef DEBUG
    NSLog(@"%s line %d, searchText: %@", __FUNCTION__, __LINE__, searchText);
#endif

    mCurrentSearch = searchText;
    
    if ([searchText length] > 2) {
        mTotalHighlightCount = (int)[self.webView highlightAllOccurencesOfString:searchText];
#ifdef DEBUG
        NSLog(@"%s line %d, highlight index: %d of %d", __FUNCTION__, __LINE__, mCurrentHightlightIndex, mTotalHighlightCount);
#endif
        mCurrentHightlightIndex = 0;
        if (mTotalHighlightCount > 1) {
            [self.webView nextHighlight:mTotalHighlightCount-1];
            [self showFindPanel:FIND_PANEL_VISIBLE];
            [self updateFindCounterLabel];
        }
        else {
            [self showFindPanel:FIND_PANEL_INVISIBLE];
        }
    }
    else {
        [self.webView removeAllHighlights];
        mTotalHighlightCount = 0;
        [self showFindPanel:FIND_PANEL_INVISIBLE];
    }
}

// Maybe the IB constraints on 'findPanel' force it to be at the visible Y
// initially, even though it was moved off screen.
// As a result the very first animation starts and ends at the same point.
- (void) showFindPanel:(FindPanelVisibility)visible
{
#ifdef DEBUG
    NSLog(@"%s line %d, visible: %ld, was %ld, frame: %@, highlight count: %d", __FUNCTION__, __LINE__,
          (long)visible,
          (long)wasVisible,
          NSStringFromCGRect(self.findPanel.frame),
          mTotalHighlightCount);
#endif

    if ((visible == wasVisible) ||
        (visible == FIND_PANEL_UNDEFINED))
    {
        // Nothing to do
#ifdef DEBUG
        NSLog(@"%s line %d Nothing to do", __FUNCTION__, __LINE__);
#endif
        return;
    }
    
    if (wasVisible == FIND_PANEL_UNDEFINED) {
        // Don't show animations to show or hide from undefined state
        [self.findPanel setHidden:YES];
#ifdef DEBUG
        NSLog(@"%s line %d, hide to/from undefined", __FUNCTION__, __LINE__);
#endif
    }
    else if (visible == FIND_PANEL_VISIBLE) {
        // Make the panel visible before the un-hiding animation starts,
        // otherwise we don't see the animation
        [self.findPanel setHidden:NO];
#ifdef DEBUG
        NSLog(@"%s line %d, show before the un-hiding animation", __FUNCTION__, __LINE__);
#endif
    }

    wasVisible = visible;
    
    CGRect newFrame = self.findPanel.frame;
    
#ifdef WITH_ANIMATION
    if (visible == FIND_PANEL_VISIBLE) {
        // newFrame.origin.x = x - 200;
        newFrame.origin.y = frameY_Visible;
  #ifdef DEBUG
        NSLog(@"%s line %d, newFrame.origin.y %f", __FUNCTION__, __LINE__, newFrame.origin.y);
  #endif
    }
    else {
        // newFrame.origin.x = x + 200;
        newFrame.origin.y = frameY_Invisible;
  #ifdef DEBUG
        NSLog(@"%s line %d, newFrame.origin.y %f", __FUNCTION__, __LINE__, newFrame.origin.y);
  #endif
    }

    __block FindPanelVisibility visibleB = visible;
  #ifdef DEBUG
    NSLog(@"%s line %d, animation start, visibleB: %ld", __FUNCTION__, __LINE__, (long)visibleB);
  #endif
    [UIView animateWithDuration:0.5f
                          delay:0.0f
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.findPanel.frame = newFrame;
                     }
                     completion:^(BOOL finished){
#ifdef DEBUG
        // finished indicates whether or not the animations actually finished before the completion handler was called.
        NSLog(@"%s line %d, animation finished: %d, visibleB: %ld", __FUNCTION__, __LINE__,
              finished, (long)visibleB);
#endif
                        // Hide it when the animation is over
                        if (visibleB == FIND_PANEL_INVISIBLE) {
                            [self.findPanel setHidden:YES];  //
#ifdef DEBUG
                            NSLog(@"%s line %d, hide panel", __FUNCTION__, __LINE__);
#endif
                        }
                     }];
#else // WITH_ANIMATION

    if (visible == FIND_PANEL_INVISIBLE) {
        [self.findPanel setHidden:YES];  //
#ifdef DEBUG
        NSLog(@"%s line %d, hide panel", __FUNCTION__, __LINE__);
#endif
    }
#endif // WITH_ANIMATION
}

#pragma mark - WKNavigationDelegate methods

- (void) webView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
 decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
#ifdef DEBUG
    NSLog(@"%s navigationType: %ld", __FUNCTION__, (long)navigationAction.navigationType);
#endif

    //if (navigationAction.navigationType == WKNavigationTypeLinkActivated)
        decisionHandler(WKNavigationActionPolicyAllow);
    //else
    //    decisionHandler(WKNavigationActionPolicyCancel);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif
    // Check this out!
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        int fontSize = 80;
        NSString *jsString = [[NSString alloc] initWithFormat:@"document.getElementsByTagName('body')[0].style.webkitTextSizeAdjust= '%d%%'", fontSize];
        [self.webView evaluateJavaScript:jsString
                       completionHandler:^(NSString* result, NSError *error) {
            if (error)
                NSLog(@"%s line %d, %@", __FUNCTION__, __LINE__, error.localizedDescription);
        }];
    }

    if ([htmlAnchor length] > 0) {
#ifdef DEBUG
        NSLog(@"%s, htmlAnchor: %@", __FUNCTION__, htmlAnchor);
#endif
        // NSString *res =
        [self.webView evaluateJavaScript:htmlAnchor
                       completionHandler:^(NSString* result, NSError *error) {
            if (error)
                NSLog(@"%s line %d, %@", __FUNCTION__, __LINE__, error.localizedDescription);
        }];
    }
    
    __block int height;
    [self.webView evaluateJavaScript:@"document.body.offsetHeight;"
                   completionHandler:^(NSString* result, NSError *error) {
        if (error)
            NSLog(@"%s line %d, %@", __FUNCTION__, __LINE__, error.localizedDescription);
        else
            height = [result intValue];
    }];

    //self.webView.scalesPageToFit = NO;  // YES
    self.webView.scrollView.zoomScale = 3.0;

#ifdef DEBUG
    NSLog(@"%s line %d, keyword:<%@>", __FUNCTION__, __LINE__, keyword);
#endif

    if ([keyword length] > 0) {
        mTotalHighlightCount = (int)[self.webView highlightAllOccurencesOfString:keyword];

        if (mTotalHighlightCount > 1)
            [self showFindPanel:FIND_PANEL_VISIBLE];
        
#ifdef DEBUG
        NSLog(@"%s line %d, highlight count: %d", __FUNCTION__, __LINE__, mTotalHighlightCount);
#endif
        [self updateFindCounterLabel];
        // TBC: as a result highlightAllOccurencesOfString is called again ?
    }
    else {
        // Hide find panel (webview is the superview of the panel)
        [self showFindPanel:FIND_PANEL_INVISIBLE];
    }
}

#pragma mark - WKUIDelegate methods

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler
{
#ifdef DEBUG
    NSLog(@"%s, defaultText: %@", __FUNCTION__, defaultText);
#endif
    completionHandler(defaultText);
}

#pragma mark - MFMailComposeViewControllerDelegate methods

- (void) mailComposeController:(MFMailComposeViewController *)controller
           didFinishWithResult:(MFMailComposeResult)result
                         error:(NSError *)error
{
    UIViewController *presentingController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    [presentingController dismissViewControllerAnimated:YES completion:nil];
    
    NSString* message = nil;
    switch (result) {
        case MFMailComposeResultCancelled:
            message = @"No mail sent at user request.";
            break;
        case MFMailComposeResultSaved:
            message = @"Draft saved";
            break;
        case MFMailComposeResultSent:
            message = @"Mail sent";
            break;
        case MFMailComposeResultFailed:
            message = @"Error";
    }
    
#ifdef DEBUG
    // Do something with the message
    NSLog(@"%s, error: %@, message: %@", __FUNCTION__, error, message);
#endif
}

// See `darkModeChanged` in AmiKo-macOS
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
#ifdef DEBUG
    NSLog(@"%s, previous style, %ld, current style:%ld", __FUNCTION__,
          (long)previousTraitCollection.userInterfaceStyle,
          [UITraitCollection currentTraitCollection].userInterfaceStyle);
#endif
    
    // Post message to switchToAips
    UIViewController *nc_rear = self.revealViewController.rearViewController;
    MLViewController *vc_rear = [nc_rear.childViewControllers firstObject];
    NSArray *toolbarItems = [vc_rear.myToolBar items];
    NSLog(@"%@", toolbarItems);
    //[vc_rear switchToAipsViewFromFulltext: messageDictionary];
}

@end
