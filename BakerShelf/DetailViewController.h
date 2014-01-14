//
//  DetailViewController.h
//  Baker
//
//  Created by Антон Малыгин on 27.12.13.
//
//

#import <UIKit/UIKit.h>
#import "IssueViewController.h"

@protocol DetailViewControllerDelegate <NSObject>

- (void)detailViewControllerDelegateShowSubscribeAlertView;

@end

@interface DetailViewController : UIViewController
@property (strong, nonatomic) IBOutlet UIScrollView *imagesScrollView;
@property (strong, nonatomic) IBOutlet UIScrollView *textScrollView;
@property (strong, nonatomic) IBOutlet UIPageControl *pageControl;
@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UIButton *favoriteButton;
@property (strong, nonatomic) IBOutlet UIButton *buyButton;
@property (strong, nonatomic) IssueViewController *issueVC;
@property (strong, nonatomic) IBOutlet UIView *backgroundForScrollView;
@property (weak) id <DetailViewControllerDelegate> delegate;
- (IBAction)buyAction:(id)sender;
- (IBAction)subscribeAction:(id)sender;
- (IBAction)favoriteAction:(id)sender;
@end
