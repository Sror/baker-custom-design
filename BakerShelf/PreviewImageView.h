//
//  PreviewImageView.h
//  Baker
//
//  Created by *** on 28.12.13.
//
//

#import <UIKit/UIKit.h>

@interface PreviewImageView : UIImageView

- (void)setUrlForDownloadImage:(NSURL *)url;
- (BOOL)isDownload;
- (void)download;

@end
