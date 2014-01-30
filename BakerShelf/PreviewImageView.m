//
//  PreviewImageView.m
//  Baker
//
//  Created by *** on 28.12.13.
//
//

#import "PreviewImageView.h"

@interface PreviewImageView ()
{
    NSURL *_urlToImage;
    BOOL _isDownload;
}

@end

@implementation PreviewImageView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setUrlForDownloadImage:(NSURL *)url
{
    _urlToImage = url;
    
    [self download];
}

- (BOOL)isDownload
{
    return _isDownload;
}

- (void)download
{
    _isDownload = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"URL %@", _urlToImage);
        NSData *data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:_urlToImage] returningResponse:nil error:nil];
        _isDownload = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (data) {
                self.image = [UIImage imageWithData:data];
            }
        });
    });
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
