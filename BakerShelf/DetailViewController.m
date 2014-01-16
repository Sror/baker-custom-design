//
//  DetailViewController.m
//  Baker
//
//  Created by Антон Малыгин on 27.12.13.
//
//

#import "DetailViewController.h"
#import "PreviewImageView.h"
#import "Utils.h"

@interface DetailViewController ()
{
    CGFloat _pageShift;
    BOOL _isScroll;
}

@end

@implementation DetailViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.layer.borderColor = [UIColor lightGrayColor].CGColor;
    self.view.layer.borderWidth = 1.0f;
    
    _isScroll = NO;
    
    self.favoriteButton.selected = _issueVC.issue.favorits;
    
    [self.buyButton setTitle:_issueVC.issue.price forState:UIControlStateNormal];
    [self.subscrButton setTitle:NSLocalizedString(@"Subscription", nil) forState:UIControlStateNormal];
    
    self.backgroundForScrollView.layer.masksToBounds = NO;
    self.backgroundForScrollView.layer.shadowRadius = 5;
    self.backgroundForScrollView.layer.shadowOpacity = 0.5;
    
    self.titleLabel.text = _issueVC.issue.title;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.backgroundForScrollView.layer.shadowOffset = CGSizeMake(2, 1);
    } else {
        self.backgroundForScrollView.layer.shadowOffset = CGSizeMake(5, 3);
    }
//    _infoLabel.text = @"Олег Митволь занимал пост префекта Северного округа столицы с июля 2009 года, а 4 октября 2010 года врио мэра Москвы Владимир Ресин подписал указ о его досрочной отставке, объяснив это тем, что методы работы Митволя не нашли поддержки среди населения округа. До этого, с 2004 года, Олег Митволь работал замруководителем Росприроднадзора.Сейчас Митволь – председатель Центрального совета экологической партии «Альянс зеленых - Народная партия». В сентябре 2012 года он участвовал в выборах мэра Химкок и занял третье место. Памятная доска – это не просто память о ком-то или чем-то, это все-таки знак почтения потомков, это то, что хочется сохранить в памяти города, - считает председатель.";
    
    CGFloat originX = 0.0;
    CGFloat originY = 0.0;
    
    NSMutableArray *array = [NSMutableArray arrayWithArray:[_issueVC.issue.previews allKeys]];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:_issueVC.issue.previews];
    [dict setObject:_issueVC.issue.info forKey:_issueVC.issue.coverPath];
    [array insertObject:_issueVC.issue.coverPath atIndex:0];
    BOOL firstObject = YES;
    for (NSString *str in array) {
        PreviewImageView *prev = [[PreviewImageView alloc] initWithFrame:CGRectMake(originX, 0.0, self.imagesScrollView.bounds.size.width, self.imagesScrollView.bounds.size.height)];
        if (firstObject) {
            [_issueVC.issue getCoverWithCache:YES andBlock:^(UIImage *img) {
                prev.image = img;
            }];
        } else {
            [_issueVC.issue getPreviewForUrl:[NSURL URLWithString:str] andBlock:^(UIImage *img) {
                prev.image = img;
            }];
        }
        [self.imagesScrollView addSubview:prev];
        originX = originX + self.imagesScrollView.bounds.size.width;
        firstObject = NO;
        
        UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, originY, self.textScrollView.bounds.size.width, self.textScrollView.bounds.size.height)];
        infoLabel.numberOfLines = 0;
        infoLabel.text = [dict objectForKey:str];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            infoLabel.textAlignment = NSTextAlignmentLeft;
        } else {
            infoLabel.textAlignment = NSTextAlignmentRight;
        }
        infoLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [self.textScrollView addSubview:infoLabel];
        
        originY = originY + self.textScrollView.bounds.size.height;
    }
    
    [self.textScrollView setContentSize:CGSizeMake(self.textScrollView.bounds.size.width, self.textScrollView.bounds.size.height*array.count)];
    
    self.pageControl.numberOfPages = array.count;
    self.pageControl.currentPage = 0;
    
    [self.imagesScrollView setContentSize:CGSizeMake(originX, self.imagesScrollView.bounds.size.height)];
    
}


- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView  {
    if (scrollView.tag == 1) {
        CGFloat pageWidth = scrollView.frame.size.width;
        float fractionalPage = scrollView.contentOffset.x / pageWidth;
        NSInteger page = lround(fractionalPage);
        self.pageControl.currentPage = page;
        
        [self.textScrollView setContentOffset:CGPointMake(0.0, self.textScrollView.bounds.size.height*page) animated:YES];
    } else if (scrollView.tag == 2) {
        CGFloat pageHeight = scrollView.frame.size.height;
        float fractionalPage = scrollView.contentOffset.y / pageHeight;
        NSInteger page = lround(fractionalPage);
        self.pageControl.currentPage = page;
        
        [self.imagesScrollView setContentOffset:CGPointMake(self.imagesScrollView.bounds.size.width*page, 0.0) animated:YES];
    }
}

//- (void)scrollViewDidScroll:(UIScrollView *)scrollView
//{
//    if (scrollView.tag == 2 && _isScroll) {
//        CGFloat pageHeight = _pageShift;
//        float fractionalPage = scrollView.contentOffset.y / pageHeight;
//        NSInteger page = lround(fractionalPage);
//        self.pageControl.currentPage = page;
//        
//        [self.imagesScrollView setContentOffset:CGPointMake(self.imagesScrollView.bounds.size.width*page, 0.0) animated:YES];
//    }
//}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    
    return YES;
}

- (IBAction)panGesture:(id)sender {
    UIPanGestureRecognizer *gesture = (UIPanGestureRecognizer *)sender;
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _isScroll = YES;
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        _isScroll = NO;
    }
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)buyAction:(id)sender {
    [_issueVC buy];
}

- (IBAction)subscribeAction:(id)sender {
    [_delegate detailViewControllerDelegateShowSubscribeAlertView];
}

- (IBAction)favoriteAction:(id)sender {
    self.favoriteButton.selected = !self.favoriteButton.selected;
    _issueVC.issue.favorits = self.favoriteButton.selected;
}

- (void)subscribe
{
    [_delegate detailViewControllerDelegateShowSubscribeAlertView];
}

@end
