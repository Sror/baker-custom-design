//
//  InfoTableViewController.m
//  Baker
//
//  Created by Антон Малыгин on 25.12.13.
//
//

#import "InfoTableViewController.h"
#import "PurchasesManager.h"

@interface InfoTableViewController ()
{
    NSArray *_subscribeArray;
    NSArray *_purchasesSection;
    NSArray *_infoSection;
}

@end

@implementation InfoTableViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        [self updateContent];
    }
    return self;
}

- (void)updateContent
{
    if ([PurchasesManager sharedInstance].subscribed) {
        _subscribeArray = [[NSArray alloc] initWithObjects:NSLocalizedString(@"SUBSCRIPTIONS_SHEET_SUBSCRIBED", nil), NSLocalizedString(@"Background downloading", nil), nil];
    } else {
        _subscribeArray = [[NSArray alloc] initWithObjects:NSLocalizedString(@"Purchase a subscription", nil), nil];
    }
    _purchasesSection = [[NSArray alloc] initWithObjects:NSLocalizedString(@"Restore purchases", nil), nil];
    _infoSection = [[NSArray alloc] initWithObjects:NSLocalizedString(@"About publishing", nil), NSLocalizedString(@"Developer", nil), nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    NSInteger rows = 0;
    if (section == 0) {
        rows = _subscribeArray.count;
    } else if (section == 1) {
        rows = _purchasesSection.count;
    } else if (section == 2) {
        rows = _infoSection.count;
    }
    return rows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"CellInfo";
    
    UISwitch *switchView = nil;
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        switchView = [[UISwitch alloc] init];
        [switchView addTarget:self action:@selector(backgroundDownAction:) forControlEvents:UIControlEventValueChanged];
        switchView.tag = 1;
        cell.accessoryView = switchView;
    }
    cell.accessoryView.hidden = YES;
    if (indexPath.section == 0) {
        if (indexPath.row > 0) {
            cell.accessoryView.hidden = NO;
            UISwitch *sw = (UISwitch *)cell.accessoryView;
            NSNumber *numb = [[NSUserDefaults standardUserDefaults] objectForKey:@"backgroundDownloading"];
            if (!numb) {
                sw.on = YES;
            } else {
                sw.on = numb.boolValue;
            }
        }
        cell.textLabel.text = [_subscribeArray objectAtIndex:indexPath.row];
    } else if (indexPath.section == 1) {
        cell.textLabel.text = [_purchasesSection objectAtIndex:indexPath.row];
    } else if (indexPath.section == 2) {
        cell.textLabel.text = [_infoSection objectAtIndex:indexPath.row];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            if (![PurchasesManager sharedInstance].subscribed)
            {
                [_delegate infoTableViewControllerDelegateDismiss];
                [_delegate infoTableViewControllerDelegateShowSubscribeAlertView];
            }
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            [[PurchasesManager sharedInstance] restore];
        }
        
    } else if (indexPath.section == 2) {
        
        if (indexPath.row == 0) {
            
            [_delegate infoTableViewControllerDelegatePushWebViewWithLink:@"http://ya.ru"];
            
        } else if (indexPath.row == 1) {
            [_delegate infoTableViewControllerDelegatePushWebViewWithLink:@"http://ya.ru"];
        }

    }
}

- (void)backgroundDownAction:(id)sender
{
    UISwitch *sw = (UISwitch *)sender;
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:sw.on] forKey:@"backgroundDownloading"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
