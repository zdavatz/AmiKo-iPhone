//
//  FullTextViewController.m
//  AmikoDesitin
//
//  Created by Alex Bettarini on 23 Jul 2019.
//  Copyright © 2019 Ywesee GmbH. All rights reserved.
//

#import "FullTextViewController.h"
#import "SWRevealViewController.h"
#import "MLUtility.h"
#import "MLViewController.h"

@interface FullTextViewController ()

@end

@implementation FullTextViewController
{
    int mNumRevealButtons;
    NSString *mTitle;
    NSString *mCurrentSearch;
}

//@synthesize webView;
@synthesize htmlStr;

+ (FullTextViewController *)sharedInstance
{
    __strong static id sharedObject = nil;
    
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        sharedObject = [self new];
    });
    
    return sharedObject;
}

- (void) viewWillAppear:(BOOL)animated
{
    if (self.htmlStr) {
        NSURL *mainBundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
#ifdef DEBUG
        NSLog(@"%s %s, mainBundleURL: %@", __FILE__, __FUNCTION__, mainBundleURL);
#endif
        // Loads HTML directly into webview
        [self.webView loadHTMLString:self.htmlStr
                             baseURL:mainBundleURL];
    }
    
    // Create objc - js bridge
    //[self createJSBridge];
}

- (void)viewDidLoad
{
#ifdef DEBUG
    NSLog(@"%s", __FUNCTION__);
#endif

    [super viewDidLoad];

    // Do any additional setup after loading the view from its nib.
    self.title = mTitle;
    self.webView.UIDelegate = self;
    //self.webView.navigationDelegate = self;
    //self.webView.scrollView.zoomScale = 3.0;

    WKWebViewConfiguration *config = self.webView.configuration;
    WKUserContentController *wkUController = config.userContentController;
    //NSLog(@"%lu userScripts: %@", (unsigned long)[wkUController.userScripts count], wkUController.userScripts);
    [wkUController addScriptMessageHandler:self name:@"buttonClicked"];
    
    // SWRevealViewController extends UIViewController!
    SWRevealViewController *revealController = [self revealViewController];
    
    [self.navigationController.navigationBar addGestureRecognizer:revealController.panGestureRecognizer];
    
    self.navigationController.navigationBar.backgroundColor = VERY_LIGHT_GRAY_COLOR;// MAIN_TINT_COLOR;
    self.navigationController.navigationBar.barTintColor = VERY_LIGHT_GRAY_COLOR;
    self.navigationController.navigationBar.translucent = NO;

    {
        UIBarButtonItem *revealButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"reveal-icon.png"]
                                         style:UIBarButtonItemStylePlain
                                        target:revealController
                                        action:@selector(revealToggle:)];
        self.navigationItem.leftBarButtonItem = revealButtonItem;
    }
    
    {
        UIBarButtonItem *rightRevealButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"reveal-icon.png"]
                                         style:UIBarButtonItemStylePlain
                                        target:revealController
                                        action:@selector(rightRevealToggle:)];
        self.navigationItem.rightBarButtonItem = rightRevealButtonItem;
    }
}

- (void) updateFullTextSearchView:(NSString *)contentStr
{
#ifdef DEBUG
    NSLog(@"%s line %d, contentStr:\n\n\n%@\n\n\n", __FUNCTION__, __LINE__,
          [contentStr substringToIndex:MIN(500,[contentStr length])]);
#endif

    NSString *color_Style =
        [NSString stringWithFormat:@"<style type=\"text/css\">%@</style>", [MLUtility getColorCss]];
    
    NSString *fulltext_Style;
    {
        // Load style sheet from file
        NSString *fullTextCssPath = [[NSBundle mainBundle] pathForResource:@"fulltext_style" ofType:@"css"];
        NSString *fullTextCss = [NSString stringWithContentsOfFile:fullTextCssPath
                                                          encoding:NSUTF8StringEncoding
                                                             error:nil];
        fulltext_Style = [NSString stringWithFormat:@"<style type=\"text/css\">%@</style>", fullTextCss];
    }

#if 0
    NSString *js_Script = @"";
#else
    // Load JavaScript from file. Do we really need this ?
    NSString *jscriptPath = [[NSBundle mainBundle] pathForResource:@"main_callbacks" ofType:@"js"];
    NSString *jscriptStr = [NSString stringWithContentsOfFile:jscriptPath
                                                     encoding:NSUTF8StringEncoding
                                                        error:nil];
    NSString *js_Script = [NSString stringWithFormat:@"<script type=\"text/javascript\">%@</script>", jscriptStr];
#endif
    
    
    NSString *charset_Meta = @"<meta charset=\"utf-8\" />";
    NSString *colorScheme_Meta= @"<meta name=\"supported-color-schemes\" content=\"light dark\" />";
    NSString *html_Head = [NSString stringWithFormat:@"<head>%@\n%@\n%@\n%@\n%@\n</head>",
                      charset_Meta,
                      colorScheme_Meta,
                      js_Script,
                      color_Style,
                      fulltext_Style];
    
    NSString *html_Body = [NSString stringWithFormat:@"<body><div id=\"fulltext\">%@</div></body>",
               contentStr];
    htmlStr = [NSString stringWithFormat:@"<html>%@\n%@\n</html>", html_Head, html_Body];
    
//#ifdef DEBUG
//    NSUInteger length = [htmlStr length];
//    
//    NSLog(@"%s line %d, htmlStr head :\n\n%@", __FUNCTION__, __LINE__,
//          [htmlStr substringToIndex:MIN(500,length)]);
//
//    NSLog(@"%s line %d, htmlStr tail :\n\n%@", __FUNCTION__, __LINE__,
//          [htmlStr substringFromIndex:length - MIN(200,length)]);
//#endif

    // Loads HTML directly into webview
    NSURL *mainBundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    [self.webView loadHTMLString:htmlStr baseURL:mainBundleURL];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - WKUIDelegate methods

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler
{
#ifdef DEBUG
    NSLog(@"%s, defaultText: %@", __FUNCTION__, defaultText);
#endif
    completionHandler(defaultText);
}

#pragma mark - WKScriptMessageHandler methods

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
{
#ifdef DEBUG
    NSLog(@"%s line %d, message.name: %@", __FUNCTION__, __LINE__, message.name);
    NSLog(@"%s line %d, message.body: %@", __FUNCTION__, __LINE__, message.body);
#endif

    if (![message.name isEqual: @"buttonClicked"])
        return;

    id messageDictionary = message.body;
    //NSLog(@"%s %d, messageBody %@",__func__, __LINE__, messageBody);
    if ([messageDictionary isKindOfClass:[NSDictionary class]]) {
//#ifdef DEBUG
//        NSLog(@"%s line %d, EanCode: %@",__func__, __LINE__, messageDictionary[@"EanCode"]);
//        NSLog(@"%s line  %d, Anchor: %@",__func__, __LINE__, messageDictionary[@"Anchor"]);
//#endif

        // Post message to switchToAips
        UIViewController *nc_rear = self.revealViewController.rearViewController;
        MLViewController *vc_rear = [nc_rear.childViewControllers firstObject];
        [vc_rear switchToAipsViewFromFulltext: messageDictionary];
    }
}

@end