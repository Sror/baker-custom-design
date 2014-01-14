//
//  ShelfViewController.m
//  Baker
//
//  ==========================================================================================
//
//  Copyright (c) 2010-2013, Davide Casali, Marco Colombo, Alessandro Morandi
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are
//  permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this list of
//  conditions and the following disclaimer.
//  Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials
//  provided with the distribution.
//  Neither the name of the Baker Framework nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
//  SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "ShelfViewController.h"
#import "UICustomNavigationBar.h"
#import "Constants.h"

#import "BakerViewController.h"
#import "IssueViewController.h"

#import "NSData+Base64.h"
#import "NSString+Extensions.h"
#import "Utils.h"
#import "WebViewController.h"


//@implementation UINavigationBar (customNav)
//- (CGSize)sizeThatFits:(CGSize)size {
//    CGSize newSize = CGSizeMake(self.frame.size.width,50.0);
//    return newSize;
//}
//@end

@interface ShelfViewController ()
{
    UITabBar *_tabBar;
    UIControl *_backView;
}

@end

@implementation ShelfViewController

@synthesize issues;
@synthesize issueViewControllers;
@synthesize gridView;
@synthesize subscribeButton;
@synthesize refreshButton;
@synthesize shelfStatus;
@synthesize subscriptionsActionSheet;
@synthesize supportedOrientation;
@synthesize blockingProgressView;
@synthesize bookToBeProcessed;

#pragma mark - Init

- (id)init {
    self = [super init];
    if (self) {
        #ifdef BAKER_NEWSSTAND
        purchasesManager = [PurchasesManager sharedInstance];
        [self addPurchaseObserver:@selector(handleProductsRetrieved:)
                             name:@"notification_products_retrieved"];
        [self addPurchaseObserver:@selector(handleProductsRequestFailed:)
                             name:@"notification_products_request_failed"];
        [self addPurchaseObserver:@selector(handleSubscriptionPurchased:)
                             name:@"notification_subscription_purchased"];
        [self addPurchaseObserver:@selector(handleSubscriptionFailed:)
                             name:@"notification_subscription_failed"];
        [self addPurchaseObserver:@selector(handleSubscriptionRestored:)
                             name:@"notification_subscription_restored"];
        [self addPurchaseObserver:@selector(handleRestoreFailed:)
                             name:@"notification_restore_failed"];
        [self addPurchaseObserver:@selector(handleMultipleRestores:)
                             name:@"notification_multiple_restores"];
        [self addPurchaseObserver:@selector(handleRestoredIssueNotRecognised:)
                             name:@"notification_restored_issue_not_recognised"];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(receiveBookProtocolNotification:)
                                                     name:@"notification_book_protocol"
                                                   object:nil];

        [[SKPaymentQueue defaultQueue] addTransactionObserver:purchasesManager];
        #endif

        api = [BakerAPI sharedInstance];
        issuesManager = [[IssuesManager sharedInstance] retain];
        notRecognisedTransactions = [[NSMutableArray alloc] init];

        self.shelfStatus = [[[ShelfStatus alloc] init] autorelease];
        self.issueViewControllers = [[[NSMutableArray alloc] init] autorelease];
        self.supportedOrientation = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UISupportedInterfaceOrientations"];
        self.bookToBeProcessed = nil;

        #ifdef BAKER_NEWSSTAND
        [self handleRefresh:nil];
        #endif
    }
    return self;
}

- (id)initWithBooks:(NSArray *)currentBooks
{
    self = [self init];
    if (self) {
        self.issues = currentBooks;

        NSMutableArray *controllers = [NSMutableArray array];
        for (BakerIssue *issue in self.issues) {
            IssueViewController *controller = [self createIssueViewControllerWithIssue:issue];
            [controllers addObject:controller];
        }
        self.issueViewControllers = [NSMutableArray arrayWithArray:controllers];
    }
    return self;
}

#pragma mark - Memory management

- (void)dealloc
{
    [gridView release];
    [issueViewControllers release];
    [issues release];
    [subscribeButton release];
    [refreshButton release];
    [shelfStatus release];
    [subscriptionsActionSheet release];
    [supportedOrientation release];
    [blockingProgressView release];
    [issuesManager release];
    [notRecognisedTransactions release];
    [bookToBeProcessed release];
    [_tabBar release];

    #ifdef BAKER_NEWSSTAND
    [purchasesManager release];
    #endif

    [super dealloc];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:217.0/255.0 green:217.0/255.0 blue:217.0/255.0 alpha:1.0];

//    self.navigationItem.title = NSLocalizedString(@"SHELF_NAVIGATION_TITLE", nil);
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"logo_title.png"]];
    imageView.frame = CGRectMake(0, 0, 300.0, 35.0);
    self.navigationItem.titleView = imageView;

    self.background = [[[UIImageView alloc] init] autorelease];

    self.gridView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[[[UICollectionViewFlowLayout alloc] init] autorelease]];
    self.gridView.dataSource = self;
    self.gridView.delegate = self;
    self.gridView.backgroundColor = [UIColor colorWithRed:217.0/255.0 green:217.0/255.0 blue:217.0/255.0 alpha:1.0];
    [self.gridView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cellIdentifier"];

    [self.view addSubview:self.background];
    [self.view addSubview:self.gridView];

    [self willRotateToInterfaceOrientation:self.interfaceOrientation duration:0];
    [self.gridView reloadData];
    
    UITabBarItem *allBooks = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Shop", nil) image:[UIImage imageNamed:@"shop.png"] selectedImage:[UIImage imageNamed:@"shop_active.png"]];
    allBooks.tag = 0;
    UITabBarItem *pBooks = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Downloads", nil) image:[UIImage imageNamed:@"down_inactive.png"] selectedImage:[UIImage imageNamed:@"down_active.png"]];
    pBooks.tag = 1;
    UITabBarItem *fBooks = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Favorits", nil) image:[UIImage imageNamed:@"fav_bar.png"] selectedImage:[UIImage imageNamed:@"fav_bar_active.png"]];
    fBooks.tag = 2;
    
    _tabBar = [[UITabBar alloc] init];
    _tabBar.delegate = self;
    _tabBar.items = [NSArray arrayWithObjects:allBooks, pBooks, fBooks, nil];
    _tabBar.selectedItem = allBooks;
    [self.view addSubview:_tabBar];
    
    [allBooks release];
    [pBooks release];
    [fBooks release];

    #ifdef BAKER_NEWSSTAND
    self.refreshButton = [[[UIBarButtonItem alloc]
                                       initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                       target:self
                                       action:@selector(handleRefresh:)]
                                      autorelease];

//    self.subscribeButton = [[[UIBarButtonItem alloc]
//                             initWithTitle: NSLocalizedString(@"SUBSCRIBE_BUTTON_TEXT", nil)
//                             style:UIBarButtonItemStylePlain
//                             target:self
//                             action:@selector(handleSubscribeButtonPressed:)]
//                            autorelease];

    self.blockingProgressView = [[UIAlertView alloc]
                                 initWithTitle:@"Processing..."
                                 message:@"\n"
                                 delegate:nil
                                 cancelButtonTitle:nil
                                 otherButtonTitles:nil];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    spinner.center = CGPointMake(139.5, 75.5); // .5 so it doesn't blur
    [self.blockingProgressView addSubview:spinner];
    [spinner startAnimating];
    [spinner release];

    NSMutableSet *subscriptions = [NSMutableSet setWithArray:AUTO_RENEWABLE_SUBSCRIPTION_PRODUCT_IDS];
    if ([FREE_SUBSCRIPTION_PRODUCT_ID length] > 0 && ![purchasesManager isPurchased:FREE_SUBSCRIPTION_PRODUCT_ID]) {
        [subscriptions addObject:FREE_SUBSCRIPTION_PRODUCT_ID];
    }
    [purchasesManager retrievePricesFor:subscriptions andEnableFailureNotifications:NO];
    #endif
}
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController.navigationBar setTranslucent:NO];
    [self willRotateToInterfaceOrientation:self.interfaceOrientation duration:0];

    for (IssueViewController *controller in self.issueViewControllers) {
        controller.issue.transientStatus = BakerIssueTransientStatusNone;
        [controller refresh];
    }

    #ifdef BAKER_NEWSSTAND
    NSMutableArray *buttonItems = [NSMutableArray arrayWithObject:self.refreshButton];
//    if ([purchasesManager hasSubscriptions] || [issuesManager hasProductIDs]) {
//        [buttonItems addObject:self.subscribeButton];
//    }
    self.navigationItem.leftBarButtonItems = buttonItems;
    #endif
    
//    UIBarButtonItem *infoButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItem target:self action:@selector(handleInfoButtonPressed:)] autorelease];
    
    UIBarButtonItem *infoButton = [[[UIBarButtonItem alloc]
                                    initWithTitle: NSLocalizedString(@"INFO_BUTTON_TEXT", nil)
                                    style:UIBarButtonItemStylePlain
                                    target:self
                                    action:@selector(handleInfoButtonPressed:)]
                                   autorelease];

    // Remove file info.html if you don't want the info button to be added to the shelf navigation bar
    NSString *infoPath = [[NSBundle mainBundle] pathForResource:@"info" ofType:@"html" inDirectory:@"info"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:infoPath]) {
        self.navigationItem.rightBarButtonItem = infoButton;
    }
}
- (void)viewDidAppear:(BOOL)animated
{
    if (self.bookToBeProcessed) {
        [self handleBookToBeProcessed];
    }
}
- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return [supportedOrientation indexOfObject:[NSString stringFromInterfaceOrientation:interfaceOrientation]] != NSNotFound;
}
- (BOOL)shouldAutorotate
{
    return YES;
}
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    int width  = 0;
    int height = 0;
    
    int widthForBack = 0;
    int heightForBack = 0;

    NSString *image = @"";
    CGSize size = [UIScreen mainScreen].bounds.size;
    int landscapePadding = 0;

    if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation)) {
        width  = size.width;
        height = size.height - 64;
        image  = @"shelf-bg-portrait";
        widthForBack = size.width;
        heightForBack = size.height;
    } else if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
        width  = size.height;
        height = size.width - 64;
        widthForBack = size.height;
        heightForBack = size.width;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            height = height + 12;
        }
        image  = @"shelf-bg-landscape";
        CGFloat cellWidth = [IssueViewController getIssueCellSize].width;
        landscapePadding = width / 4 - cellWidth / 2;
    }

    if (size.height == 568) {
        image = [NSString stringWithFormat:@"%@-568h", image];
    } else {
        image = [NSString stringWithFormat:@"%@", image];
    }

//    int bannerHeight = [ShelfViewController getBannerHeight];
    int bannerHeight = 0;

    self.background.frame = CGRectMake(0, 0, width, height);
//    self.background.image = [UIImage imageNamed:image];

    self.gridView.frame = CGRectMake(landscapePadding, bannerHeight, width - 2 * landscapePadding, height - bannerHeight);
    _tabBar.frame = CGRectMake(0, height - 60.0, width, 60.0);
    
    if (_backView) {
        _backView.frame = CGRectMake(0, 0, widthForBack, heightForBack);
        UIView *sub = [_backView.subviews firstObject];
        sub.center = _backView.center;
    }
}
- (IssueViewController *)createIssueViewControllerWithIssue:(BakerIssue *)issue
{
    IssueViewController *controller = [[[IssueViewController alloc] initWithBakerIssue:issue] autorelease];
    controller.delegate = self;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleReadIssue:) name:@"read_issue_request" object:controller];
    return controller;
}

#pragma mark - Shelf data source

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [issueViewControllers count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGSize cellSize = [IssueViewController getIssueCellSize];
    CGRect cellFrame = CGRectMake(0, 0, cellSize.width, cellSize.height);

    static NSString *cellIdentifier = @"cellIdentifier";
    UICollectionViewCell* cell = [self.gridView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
	if (cell == nil)
	{
		UICollectionViewCell* cell = [[[UICollectionViewCell alloc] initWithFrame:cellFrame] autorelease];

        cell.contentView.backgroundColor = [UIColor clearColor];
        cell.backgroundColor = [UIColor clearColor];
	}

    IssueViewController *controller = [self.issueViewControllers objectAtIndex:indexPath.row];
    UIView *removableIssueView = [cell.contentView viewWithTag:42];
    if (removableIssueView) {
        [removableIssueView removeFromSuperview];
    }
    [cell.contentView addSubview:controller.view];

    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [IssueViewController getIssueCellSize];
}

#ifdef BAKER_NEWSSTAND

- (void)handleRefreshDownloading
{
    self.issues = issuesManager.issues;
    
    NSMutableArray *arr = [NSMutableArray array];
    for (BakerIssue *issue in self.issues) {
        if ([[issue getStatus] isEqualToString:@"downloaded"]) {
            [arr addObject:issue];
        }
    }
    
    NSMutableArray *arrControllers = [NSMutableArray array];
    // Step 2: add controllers for issues that did not yet exist (and refresh the ones that do exist)
    [arr enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        // NOTE: this block changes the issueViewController array while looping
        BakerIssue *issue = (BakerIssue *)obj;
        
        IssueViewController *existingIvc = [self issueViewControllerWithID:issue.ID];
        
        if (existingIvc) {
            [arrControllers addObject:existingIvc];
        } else {
            existingIvc = [self createIssueViewControllerWithIssue:issue];
            [arrControllers addObject:existingIvc];
        }
    }];
    self.issueViewControllers = arrControllers;
    [self.gridView reloadData];
    
}

- (void)handleRefreshFavorits
{
    self.issues = issuesManager.issues;
    
    NSMutableArray *arr = [NSMutableArray array];
    for (BakerIssue *issue in self.issues) {
        if (issue.favorits) {
            [arr addObject:issue];
        }
    }
    
    NSMutableArray *arrControllers = [NSMutableArray array];
    // Step 2: add controllers for issues that did not yet exist (and refresh the ones that do exist)
    [arr enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        // NOTE: this block changes the issueViewController array while looping
        BakerIssue *issue = (BakerIssue *)obj;
        
        IssueViewController *existingIvc = [self issueViewControllerWithID:issue.ID];
        
        if (existingIvc) {
            [arrControllers addObject:existingIvc];
        } else {
            existingIvc = [self createIssueViewControllerWithIssue:issue];
            [arrControllers addObject:existingIvc];
        }
    }];
    self.issueViewControllers = arrControllers;
    [self.gridView reloadData];
}

- (void)handleRefreshAllObject
{
    self.issues = issuesManager.issues;
    
    [shelfStatus load];
    for (BakerIssue *issue in self.issues) {
        issue.price = [shelfStatus priceFor:issue.productID];
    }
    
    void (^updateIssues)() = ^{
        // Step 1: remove controllers for issues that no longer exist
        __block NSMutableArray *discardedControllers = [NSMutableArray array];
        [self.issueViewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            IssueViewController *ivc = (IssueViewController *)obj;
            
            if (![self bakerIssueWithID:ivc.issue.ID]) {
                [discardedControllers addObject:ivc];
                [self.gridView deleteItemsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForItem:idx inSection:0]]];
            }
        }];
        [self.issueViewControllers removeObjectsInArray:discardedControllers];
        
        // Step 2: add controllers for issues that did not yet exist (and refresh the ones that do exist)
        [self.issues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            // NOTE: this block changes the issueViewController array while looping
            BakerIssue *issue = (BakerIssue *)obj;
            
            IssueViewController *existingIvc = [self issueViewControllerWithID:issue.ID];
            
            if (existingIvc) {
                existingIvc.issue = issue;
            } else {
                IssueViewController *newIvc = [self createIssueViewControllerWithIssue:issue];
                [self.issueViewControllers insertObject:newIvc atIndex:idx];
                [self.gridView insertItemsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForItem:idx inSection:0] ] ];
            }
        }];
        
        [self.gridView reloadData];
    };
    
    // When first launched, the grid is not initialised, so we can't
    // call in the "batch update" method of the grid view
    if (self.gridView) {
        [self.gridView performBatchUpdates:updateIssues completion:nil];
    }
    else {
        updateIssues();
    }
    
    [purchasesManager retrievePurchasesFor:[issuesManager productIDs] withCallback:^(NSDictionary *purchases) {
        // List of purchases has been returned, so we can refresh all issues
        [self.issueViewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [(IssueViewController *)obj refreshContentWithCache:NO];
        }];
        [self setrefreshButtonEnabled:YES];
    }];
    
    [purchasesManager retrievePricesFor:issuesManager.productIDs andEnableFailureNotifications:NO];
}

- (void)handleRefresh:(NSNotification *)notification {
    [self setrefreshButtonEnabled:NO];
    
    if (_tabBar) {
        _tabBar.selectedItem = [_tabBar.items firstObject];
    }

    [issuesManager refresh:^(BOOL status) {
        if(status) {
            self.issues = issuesManager.issues;

            [shelfStatus load];
            for (BakerIssue *issue in self.issues) {
                issue.price = [shelfStatus priceFor:issue.productID];
            }

            void (^updateIssues)() = ^{
                // Step 1: remove controllers for issues that no longer exist
                __block NSMutableArray *discardedControllers = [NSMutableArray array];
                [self.issueViewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    IssueViewController *ivc = (IssueViewController *)obj;

                    if (![self bakerIssueWithID:ivc.issue.ID]) {
                        [discardedControllers addObject:ivc];
                        [self.gridView deleteItemsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForItem:idx inSection:0]]];
                    }
                }];
                [self.issueViewControllers removeObjectsInArray:discardedControllers];

                // Step 2: add controllers for issues that did not yet exist (and refresh the ones that do exist)
                [self.issues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    // NOTE: this block changes the issueViewController array while looping
                    BakerIssue *issue = (BakerIssue *)obj;

                    IssueViewController *existingIvc = [self issueViewControllerWithID:issue.ID];

                    if (existingIvc) {
                        existingIvc.issue = issue;
                    } else {
                        IssueViewController *newIvc = [self createIssueViewControllerWithIssue:issue];
                        [self.issueViewControllers insertObject:newIvc atIndex:idx];
                        [self.gridView insertItemsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForItem:idx inSection:0] ] ];
                    }
                }];

                [self.gridView reloadData];
            };

            // When first launched, the grid is not initialised, so we can't
            // call in the "batch update" method of the grid view
            if (self.gridView) {
                [self.gridView performBatchUpdates:updateIssues completion:nil];
            }
            else {
                updateIssues();
            }

            [purchasesManager retrievePurchasesFor:[issuesManager productIDs] withCallback:^(NSDictionary *purchases) {
                // List of purchases has been returned, so we can refresh all issues
                [self.issueViewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [(IssueViewController *)obj refreshContentWithCache:NO];
                }];
                [self setrefreshButtonEnabled:YES];
            }];

            [purchasesManager retrievePricesFor:issuesManager.productIDs andEnableFailureNotifications:NO];
        } else {
            [Utils showAlertWithTitle:NSLocalizedString(@"INTERNET_CONNECTION_UNAVAILABLE_TITLE", nil)
                              message:NSLocalizedString(@"INTERNET_CONNECTION_UNAVAILABLE_MESSAGE", nil)
                          buttonTitle:NSLocalizedString(@"INTERNET_CONNECTION_UNAVAILABLE_CLOSE", nil)];
            [self setrefreshButtonEnabled:YES];
        }
    }];
}

- (IssueViewController *)issueViewControllerWithID:(NSString *)ID {
    __block IssueViewController* foundController = nil;
    [self.issueViewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        IssueViewController *ivc = (IssueViewController *)obj;
        if ([ivc.issue.ID isEqualToString:ID]) {
            foundController = ivc;
            *stop = YES;
        }
    }];
    return foundController;
}

- (BakerIssue *)bakerIssueWithID:(NSString *)ID {
    __block BakerIssue *foundIssue = nil;
    [self.issues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        BakerIssue *issue = (BakerIssue *)obj;
        if ([issue.ID isEqualToString:ID]) {
            foundIssue = issue;
            *stop = YES;
        }
    }];
    return foundIssue;
}

#pragma mark - Store Kit
- (void)handleSubscribeButtonPressed:(NSNotification *)notification {
    if (subscriptionsActionSheet.visible) {
        [subscriptionsActionSheet dismissWithClickedButtonIndex:(subscriptionsActionSheet.numberOfButtons - 1) animated:YES];
    } else {
        self.subscriptionsActionSheet = [self buildSubscriptionsActionSheet];
//        [subscriptionsActionSheet showFromBarButtonItem:self.subscribeButton animated:YES];
    }
}

- (UIActionSheet *)buildSubscriptionsActionSheet {
    NSString *title;
    if ([api canGetPurchasesJSON]) {
        if (purchasesManager.subscribed) {
            title = NSLocalizedString(@"SUBSCRIPTIONS_SHEET_SUBSCRIBED", nil);
        } else {
            title = NSLocalizedString(@"SUBSCRIPTIONS_SHEET_NOT_SUBSCRIBED", nil);
        }
    } else {
        title = NSLocalizedString(@"SUBSCRIPTIONS_SHEET_GENERIC", nil);
    }

    UIActionSheet *sheet = [[UIActionSheet alloc]initWithTitle:title
                                                      delegate:self
                                             cancelButtonTitle:nil
                                        destructiveButtonTitle:nil
                                             otherButtonTitles: nil];
    NSMutableArray *actions = [NSMutableArray array];

    if (!purchasesManager.subscribed) {
        if ([FREE_SUBSCRIPTION_PRODUCT_ID length] > 0 && ![purchasesManager isPurchased:FREE_SUBSCRIPTION_PRODUCT_ID]) {
            [sheet addButtonWithTitle:NSLocalizedString(@"SUBSCRIPTIONS_SHEET_FREE", nil)];
            [actions addObject:FREE_SUBSCRIPTION_PRODUCT_ID];
        }

        for (NSString *productId in AUTO_RENEWABLE_SUBSCRIPTION_PRODUCT_IDS) {
            NSString *title = NSLocalizedString(productId, nil);
            NSString *price = [purchasesManager priceFor:productId];
            if (price) {
                [sheet addButtonWithTitle:[NSString stringWithFormat:@"%@ %@", title, price]];
                [actions addObject:productId];
            }
        }
    }

    if ([issuesManager hasProductIDs]) {
        [sheet addButtonWithTitle:NSLocalizedString(@"SUBSCRIPTIONS_SHEET_RESTORE", nil)];
        [actions addObject:@"restore"];
    }

    [sheet addButtonWithTitle:NSLocalizedString(@"SUBSCRIPTIONS_SHEET_CLOSE", nil)];
    [actions addObject:@"cancel"];

    self.subscriptionsActionSheetActions = actions;

    sheet.cancelButtonIndex = sheet.numberOfButtons - 1;
    return sheet;
}

- (void)buildSubscriptionsAlertView {
    NSString *title;
    if ([api canGetPurchasesJSON]) {
        if (purchasesManager.subscribed) {
            title = NSLocalizedString(@"SUBSCRIPTIONS_SHEET_SUBSCRIBED", nil);
        } else {
            title = NSLocalizedString(@"SUBSCRIPTIONS_SHEET_NOT_SUBSCRIBED", nil);
        }
    } else {
        title = NSLocalizedString(@"SUBSCRIPTIONS_SHEET_GENERIC", nil);
    }
    NSString *message;
    message = NSLocalizedString(@"SUBSCRIPTIONS_MESSAGE_AUTO", nil);
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
    alertView.tag = 2000;
    
    NSMutableArray *actions = [NSMutableArray array];
    
    if (!purchasesManager.subscribed) {
        if ([FREE_SUBSCRIPTION_PRODUCT_ID length] > 0 && ![purchasesManager isPurchased:FREE_SUBSCRIPTION_PRODUCT_ID]) {
            [alertView addButtonWithTitle:NSLocalizedString(@"SUBSCRIPTIONS_SHEET_FREE", nil)];
            [actions addObject:FREE_SUBSCRIPTION_PRODUCT_ID];
        }
        
        for (NSString *productId in AUTO_RENEWABLE_SUBSCRIPTION_PRODUCT_IDS) {
            NSString *title = NSLocalizedString(productId, nil);
            NSString *price = [purchasesManager priceFor:productId];
            if (price) {
                [alertView addButtonWithTitle:[NSString stringWithFormat:@"%@ %@", title, price]];
                [actions addObject:productId];
            }
        }
    }
    
    if ([issuesManager hasProductIDs]) {
        [alertView addButtonWithTitle:NSLocalizedString(@"SUBSCRIPTIONS_SHEET_RESTORE", nil)];
        [actions addObject:@"restore"];
    }
    
    [alertView addButtonWithTitle:NSLocalizedString(@"SUBSCRIPTIONS_SHEET_CLOSE", nil)];
    [actions addObject:@"cancel"];
    
    self.subscriptionsActionSheetActions = actions;
    
    alertView.cancelButtonIndex = alertView.numberOfButtons - 1;
    [alertView show];
    [alertView release];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet == subscriptionsActionSheet) {
        NSString *action = [self.subscriptionsActionSheetActions objectAtIndex:buttonIndex];
        if ([action isEqualToString:@"cancel"]) {
            NSLog(@"Action sheet: cancel");
            [self setSubscribeButtonEnabled:YES];
        } else if ([action isEqualToString:@"restore"]) {
            [self.blockingProgressView show];
            [purchasesManager restore];
            NSLog(@"Action sheet: restore");
        } else {
            NSLog(@"Action sheet: %@", action);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"BakerSubscriptionPurchase" object:self]; // -> Baker Analytics Event
            [self setSubscribeButtonEnabled:NO];
            if (![purchasesManager purchase:action]){
                [Utils showAlertWithTitle:NSLocalizedString(@"SUBSCRIPTION_FAILED_TITLE", nil)
                                  message:nil
                              buttonTitle:NSLocalizedString(@"SUBSCRIPTION_FAILED_CLOSE", nil)];
                [self setSubscribeButtonEnabled:YES];
            }
        }
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 2000) {
        NSString *action = [self.subscriptionsActionSheetActions objectAtIndex:buttonIndex];
        if ([action isEqualToString:@"cancel"]) {
            NSLog(@"Action sheet: cancel");
            [self setSubscribeButtonEnabled:YES];
        } else if ([action isEqualToString:@"restore"]) {
            [self.blockingProgressView show];
            [purchasesManager restore];
            NSLog(@"Action sheet: restore");
        } else {
            NSLog(@"Action sheet: %@", action);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"BakerSubscriptionPurchase" object:self]; // -> Baker Analytics Event
            [self setSubscribeButtonEnabled:NO];
            if (![purchasesManager purchase:action]){
                [Utils showAlertWithTitle:NSLocalizedString(@"SUBSCRIPTION_FAILED_TITLE", nil)
                                  message:nil
                              buttonTitle:NSLocalizedString(@"SUBSCRIPTION_FAILED_CLOSE", nil)];
                [self setSubscribeButtonEnabled:YES];
            }
        }
    }
}

- (void)handleRestoreFailed:(NSNotification *)notification {
    NSError *error = [notification.userInfo objectForKey:@"error"];
    [Utils showAlertWithTitle:NSLocalizedString(@"RESTORE_FAILED_TITLE", nil)
                      message:[error localizedDescription]
                  buttonTitle:NSLocalizedString(@"RESTORE_FAILED_CLOSE", nil)];

    [self.blockingProgressView dismissWithClickedButtonIndex:0 animated:YES];

}

- (void)handleMultipleRestores:(NSNotification *)notification {
    #ifdef BAKER_NEWSSTAND
    if ([notRecognisedTransactions count] > 0) {
        NSSet *productIDs = [NSSet setWithArray:[[notRecognisedTransactions valueForKey:@"payment"] valueForKey:@"productIdentifier"]];
        NSString *productsList = [[productIDs allObjects] componentsJoinedByString:@", "];

        [Utils showAlertWithTitle:NSLocalizedString(@"RESTORED_ISSUE_NOT_RECOGNISED_TITLE", nil)
                          message:[NSString stringWithFormat:NSLocalizedString(@"RESTORED_ISSUE_NOT_RECOGNISED_MESSAGE", nil), productsList]
                      buttonTitle:NSLocalizedString(@"RESTORED_ISSUE_NOT_RECOGNISED_CLOSE", nil)];

        for (SKPaymentTransaction *transaction in notRecognisedTransactions) {
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        }
        [notRecognisedTransactions removeAllObjects];
    }
    #endif

    [self handleRefresh:nil];
    [self.blockingProgressView dismissWithClickedButtonIndex:0 animated:YES];
}

- (void)handleRestoredIssueNotRecognised:(NSNotification *)notification {
    SKPaymentTransaction *transaction = [notification.userInfo objectForKey:@"transaction"];
    [notRecognisedTransactions addObject:transaction];
}

// TODO: this can probably be removed
- (void)handleSubscription:(NSNotification *)notification {
    [self setSubscribeButtonEnabled:NO];
    [purchasesManager purchase:FREE_SUBSCRIPTION_PRODUCT_ID];
}

- (void)handleSubscriptionPurchased:(NSNotification *)notification {
    SKPaymentTransaction *transaction = [notification.userInfo objectForKey:@"transaction"];

    [purchasesManager markAsPurchased:transaction.payment.productIdentifier];
    [self setSubscribeButtonEnabled:YES];

    if ([purchasesManager finishTransaction:transaction]) {
        if (!purchasesManager.subscribed) {
            [Utils showAlertWithTitle:NSLocalizedString(@"SUBSCRIPTION_SUCCESSFUL_TITLE", nil)
                              message:NSLocalizedString(@"SUBSCRIPTION_SUCCESSFUL_MESSAGE", nil)
                          buttonTitle:NSLocalizedString(@"SUBSCRIPTION_SUCCESSFUL_CLOSE", nil)];

            [self handleRefresh:nil];
        }
    } else {
        [Utils showAlertWithTitle:NSLocalizedString(@"TRANSACTION_RECORDING_FAILED_TITLE", nil)
                          message:NSLocalizedString(@"TRANSACTION_RECORDING_FAILED_MESSAGE", nil)
                      buttonTitle:NSLocalizedString(@"TRANSACTION_RECORDING_FAILED_CLOSE", nil)];
    }
}

- (void)handleSubscriptionFailed:(NSNotification *)notification {
    SKPaymentTransaction *transaction = [notification.userInfo objectForKey:@"transaction"];

    // Show an error, unless it was the user who cancelled the transaction
    if (transaction.error.code != SKErrorPaymentCancelled) {
        [Utils showAlertWithTitle:NSLocalizedString(@"SUBSCRIPTION_FAILED_TITLE", nil)
                          message:[transaction.error localizedDescription]
                      buttonTitle:NSLocalizedString(@"SUBSCRIPTION_FAILED_CLOSE", nil)];
    }

    [self setSubscribeButtonEnabled:YES];
}

- (void)handleSubscriptionRestored:(NSNotification *)notification {
    SKPaymentTransaction *transaction = [notification.userInfo objectForKey:@"transaction"];

    [purchasesManager markAsPurchased:transaction.payment.productIdentifier];

    if (![purchasesManager finishTransaction:transaction]) {
        NSLog(@"Could not confirm purchase restore with remote server for %@", transaction.payment.productIdentifier);
    }
}

- (void)handleProductsRetrieved:(NSNotification *)notification {
    NSSet *ids = [notification.userInfo objectForKey:@"ids"];
    BOOL issuesRetrieved = NO;

    for (NSString *productId in ids) {
        if ([productId isEqualToString:FREE_SUBSCRIPTION_PRODUCT_ID]) {
            // ID is for a free subscription
            [self setSubscribeButtonEnabled:YES];
        } else if ([AUTO_RENEWABLE_SUBSCRIPTION_PRODUCT_IDS containsObject:productId]) {
            // ID is for an auto-renewable subscription
            [self setSubscribeButtonEnabled:YES];
        } else {
            // ID is for an issue
            issuesRetrieved = YES;
        }
    }

    if (issuesRetrieved) {
        NSString *price;
        for (IssueViewController *controller in self.issueViewControllers) {
            price = [purchasesManager priceFor:controller.issue.productID];
            if (price) {
                [controller setPrice:price];
                [shelfStatus setPrice:price for:controller.issue.productID];
            }
        }
        [shelfStatus save];
    }
}

- (void)handleProductsRequestFailed:(NSNotification *)notification {
    NSError *error = [notification.userInfo objectForKey:@"error"];

    [Utils showAlertWithTitle:NSLocalizedString(@"PRODUCTS_REQUEST_FAILED_TITLE", nil)
                      message:[error localizedDescription]
                  buttonTitle:NSLocalizedString(@"PRODUCTS_REQUEST_FAILED_CLOSE", nil)];
}

#endif

#pragma mark - Navigation management

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
}

- (void)readIssue:(BakerIssue *)issue
{
    BakerBook *book = nil;
    NSString *status = [issue getStatus];

    #ifdef BAKER_NEWSSTAND
    if ([status isEqual:@"opening"]) {
        
        if (issue.isPDF) {
            ReaderDocument *document = [ReaderDocument withDocumentFilePath:issue.realPath password:nil name:issue.title];
            
            if (document != nil) // Must have a valid ReaderDocument object in order to proceed with things
            {
                ReaderViewController *readerViewController = [[ReaderViewController alloc] initWithReaderDocument:document];
                
                readerViewController.delegate = self;
                [self.navigationController pushViewController:readerViewController animated:YES];
                [readerViewController release];
            }
        } else {
            book = [[[BakerBook alloc] initWithBookPath:issue.path bundled:NO] autorelease];
            if (book) {
                [self pushViewControllerWithBook:book];
            } else {
                NSLog(@"[ERROR] Book %@ could not be initialized", issue.ID);
                issue.transientStatus = BakerIssueTransientStatusNone;
                // Let's refresh everything as it's easier. This is an edge case anyway ;)
                for (IssueViewController *controller in issueViewControllers) {
                    [controller refresh];
                }
                [Utils showAlertWithTitle:NSLocalizedString(@"ISSUE_OPENING_FAILED_TITLE", nil)
                                  message:NSLocalizedString(@"ISSUE_OPENING_FAILED_MESSAGE", nil)
                              buttonTitle:NSLocalizedString(@"ISSUE_OPENING_FAILED_CLOSE", nil)];
            }
        }
    }
    #else
    if ([status isEqual:@"bundled"]) {
        book = [issue bakerBook];
        [self pushViewControllerWithBook:book];
    }
    #endif
}
- (void)handleReadIssue:(NSNotification *)notification
{
    IssueViewController *controller = notification.object;
    [self readIssue:controller.issue];
}
- (void)receiveBookProtocolNotification:(NSNotification *)notification
{
    self.bookToBeProcessed = [notification.userInfo objectForKey:@"ID"];
    [self.navigationController popToRootViewControllerAnimated:YES];
}
- (void)handleBookToBeProcessed
{
    for (IssueViewController *issueViewController in self.issueViewControllers) {
        if ([issueViewController.issue.ID isEqualToString:self.bookToBeProcessed]) {
            [issueViewController actionButtonPressed:nil];
            break;
        }
    }

    self.bookToBeProcessed = nil;
}
- (void)pushViewControllerWithBook:(BakerBook *)book
{
    BakerViewController *bakerViewController = [[BakerViewController alloc] initWithBook:book];
    [self.navigationController pushViewController:bakerViewController animated:YES];
    [bakerViewController release];
}

#pragma mark - Buttons management

-(void)setrefreshButtonEnabled:(BOOL)enabled {
    self.refreshButton.enabled = enabled;
}

-(void)setSubscribeButtonEnabled:(BOOL)enabled {
//    self.subscribeButton.enabled = enabled;
//    if (enabled) {
//        self.subscribeButton.title = NSLocalizedString(@"SUBSCRIBE_BUTTON_TEXT", nil);
//    } else {
//        self.subscribeButton.title = NSLocalizedString(@"SUBSCRIBE_BUTTON_DISABLED_TEXT", nil);
//    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    // Inject user_id
    [Utils webView:webView dispatchHTMLEvent:@"init" withParams:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                [BakerAPI UUID], @"user_id",
                                                                [Utils appID], @"app_id",
                                                                nil]];
}

- (void)handleInfoButtonPressed:(id)sender {
    
    // If the button is pressed when the info box is open, close it
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        if ([infoPopover isPopoverVisible])
        {
            [infoPopover dismissPopoverAnimated:YES];
            return;
        }
    }
    
    // Prepare new view
//    UIViewController *popoverContent = [[UIViewController alloc] init];
    InfoTableViewController *popoverContent = [[InfoTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    popoverContent.delegate = self;
    
    UINavigationController *navigController = [[UINavigationController alloc] initWithRootViewController:popoverContent];
//    UIWebView *popoverView = [[UIWebView alloc] init];
//    popoverView.backgroundColor = [UIColor blackColor];
//    popoverView.delegate = self;
//    popoverContent.view = popoverView;
    
    // Load HTML file
//    NSString *path = [[NSBundle mainBundle] pathForResource:@"info" ofType:@"html" inDirectory:@"info"];
//    [popoverView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]]];
    
    // Open view
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    {
        // On iPad use the UIPopoverController
        infoPopover = [[UIPopoverController alloc] initWithContentViewController:navigController];
        [infoPopover setPopoverContentSize:CGSizeMake(320.0, 400.0)];
        [infoPopover presentPopoverFromBarButtonItem:sender
                            permittedArrowDirections:UIPopoverArrowDirectionUp
                                            animated:YES];
    }
    else {
        // On iPhone push the view controller to the navigation
        [self.navigationController pushViewController:popoverContent animated:YES];
    }
    
//    [popoverView release];
    [popoverContent release];
}

#pragma mark - Helper methods

- (void)addPurchaseObserver:(SEL)notificationSelector name:(NSString *)notificationName {
    #ifdef BAKER_NEWSSTAND
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:notificationSelector
                                                 name:notificationName
                                               object:purchasesManager];
    #endif
}

+ (int)getBannerHeight
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return 240;
    } else {
        return 104;
    }
}

#pragma mark ReaderViewControllerDelegate methods

- (void)dismissReaderViewController:(ReaderViewController *)viewController
{
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    switch (item.tag) {
        case 0:
            [self handleRefreshAllObject];
            break;
        case 1:
            [self handleRefreshDownloading];
            break;
        case 2:
            [self handleRefreshFavorits];
            break;
            
        default:
            break;
    }
}

- (void)showViewController:(UIViewController *)controller
{
    DetailViewController *detCont = (DetailViewController *)controller;
    detCont.delegate = self;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.navigationController pushViewController:controller animated:YES];
    } else {
        _backView = [[UIControl alloc] initWithFrame:self.navigationController.view.bounds];
        _backView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
        [_backView addTarget:self action:@selector(handleTapBackView:) forControlEvents:UIControlEventTouchDown];
        controller.view.center = _backView.center;
        [_backView addSubview:controller.view];
        [UIView transitionWithView:self.navigationController.view duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
            [self.navigationController.view addSubview:_backView];
        } completion:^(BOOL finished) {
            
        }];
    }
}

- (void)handleTapBackView:(id)sender
{
    UIControl *view = (UIControl *)sender;
    [UIView transitionWithView:self.navigationController.view duration:0.25 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        [view removeFromSuperview];
    } completion:^(BOOL finished) {
        [_backView release];
        _backView = nil;
    }];
}

- (void)infoTableViewControllerDelegateShowSubscribeAlertView
{
    [self buildSubscriptionsAlertView];
}

- (void)infoTableViewControllerDelegateDismissAnimated:(BOOL)animated
{
    [infoPopover dismissPopoverAnimated:animated];
}

- (void)detailViewControllerDelegateShowSubscribeAlertView
{
    [self buildSubscriptionsAlertView];
}

- (void)infoTableViewControllerDelegatePushWebViewWithLink:(NSString *)link
{
    WebViewController *webVC = [[WebViewController alloc] initWithLink:link];
    [self.navigationController pushViewController:webVC animated:YES];
    [webVC release];
}

@end
