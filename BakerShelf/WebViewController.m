//
//  WebViewController.m
//  Baker
//
//  Created by Антон Малыгин on 14.01.14.
//
//

#import "WebViewController.h"

@interface WebViewController ()
{
    UIWebView *_webView;
    NSString *_link;
}

@end

@implementation WebViewController

- (id)initWithLink:(NSString *)link
{
    self = [super init];
    if (self) {
        _link = link;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _webView = [[UIWebView alloc] init];
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:_link]]];
    [self.view addSubview:_webView];
	// Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    _webView.frame = self.view.bounds;
}

- (void)viewWillLayoutSubviews
{
    _webView.frame = self.view.bounds;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
