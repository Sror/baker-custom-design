//
//  InfoTableViewController.h
//  Baker
//
//  Created by *** on 25.12.13.
//
//

#import <UIKit/UIKit.h>

@protocol InfoTableViewControllerDelegate <NSObject>

- (void)infoTableViewControllerDelegateShowSubscribeAlertView;
- (void)infoTableViewControllerDelegateDismissAnimated:(BOOL)animated;
- (void)infoTableViewControllerDelegatePushWebViewWithLink:(NSString *)link;

@end

@interface InfoTableViewController : UITableViewController

@property (weak) id <InfoTableViewControllerDelegate> delegate;

@end
