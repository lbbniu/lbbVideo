//
//  LBModuleCCVideo.h
//  UZApp
//
//  Created by 刘兵兵 on 15/11/5.
//  Copyright (c) 2015年 APICloud. All rights reserved.
//

#import "UZModule.h"
#import "DWDownloader.h"
#import "DWDownloadItem.h"
@interface LBModuleCCVideo : UZModule

@property (copy, nonatomic)NSString *videoId;
@property (copy, nonatomic)NSString *videoLocalPath;
@property (copy, nonatomic)NSString *downloadVideoId;
@property (copy, nonatomic)NSString *progress;
@end
