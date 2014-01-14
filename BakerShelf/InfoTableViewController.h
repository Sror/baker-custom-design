//
//  InfoTableViewController.h
//  Baker
//
//  Created by Антон Малыгин on 25.12.13.
//
//

#import <UIKit/UIKit.h>

@protocol InfoTableViewControllerDelegate <NSObject>

- (void)infoTableViewControllerDelegateShowSubscribeAlertView;
- (void)infoTableViewControllerDelegateDismiss;
- (void)infoTableViewControllerDelegatePushWebViewWithLink:(NSString *)link;

@end

@interface InfoTableViewController : UITableViewController

@property (weak) id <InfoTableViewControllerDelegate> delegate;

@end
