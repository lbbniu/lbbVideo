//
//  LBModuleCCVideo.m
//  UZApp
//
//  Created by 刘兵兵 on 15/11/5.
//  Copyright (c) 2015年 APICloud. All rights reserved.
//

#import "LBModuleCCVideo.h"
#import "UZAppDelegate.h"
#import "NSDictionaryUtils.h"

///lbbbb
#import <UIKit/UIKit.h>
#import "DWSDK.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "DWPlayerMenuView.h"
#import "DWTableView.h"
#import "DWTools.h"
#import "DWMediaSubtitle.h"
#import "DWDrmServer.h"

#define logerror(format, ...) NSLog(@"%s():%d ERROR============ "format, __func__, __LINE__, ##__VA_ARGS__)
#define logdebug(format, ...) NSLog(@"%s():%d DEBUG------------ "format, __func__, __LINE__, ##__VA_ARGS__)

enum {
    DWPlayerScreenSizeModeFill=1,
    DWPlayerScreenSizeMode100,
    DWPlayerScreenSizeMode75,
    DWPlayerScreenSizeMode50
};

typedef NSInteger DWPLayerScreenSizeMode;

@interface LBModuleCCVideo ()<UIAlertViewDelegate,UIGestureRecognizerDelegate>
{
    NSInteger _cbId;
    NSString  *title;
    NSString *userId;
    NSString *apiKey;
    NSInteger definition;
    NSInteger isEncryption;
    float viewx;
    float viewy;
    float viewwidth;
    float viewheight;
    DWDownloader *downloader;
}
@property (strong, nonatomic)UIView *headerView;
@property (strong, nonatomic)UIView *footerView;

@property (strong, nonatomic)UIButton *backButton;

@property (strong, nonatomic)UIButton *screenSizeButton;
@property (strong, nonatomic)DWPlayerMenuView *screenSizeView;
@property (assign, nonatomic)NSInteger currentScreenSizeStatus;
@property (strong, nonatomic)DWTableView *screenSizeTable;

@property (strong, nonatomic)DWPlayerMenuView *subtitleView;
@property (strong, nonatomic)UILabel *movieSubtitleLabel;
@property (strong, nonatomic)DWMediaSubtitle *mediaSubtitle;

@property (strong, nonatomic)UIButton *qualityButton;

@property (strong, nonatomic)UIButton *playpreButton;
@property (strong, nonatomic)UIButton *playbackButton;
@property (strong, nonatomic)UIButton *playnextButton;
//  倍率  声音 笔记 提问 讲义
@property (strong, nonatomic)UIButton *playbeilvButton;
@property (strong, nonatomic)UIButton *playvolumeButton;
@property (strong, nonatomic)UIButton *playbijiButton;
@property (strong, nonatomic)UIButton *playtiwenButton;
@property (strong, nonatomic)UIButton *playjiangyiButton;



@property (strong, nonatomic)UISlider *durationSlider;
@property (strong, nonatomic)UILabel *duration_CurrentPlaybackTimeLabel;
@property (strong, nonatomic)UILabel *currentPlaybackTimeLabel;
@property (strong, nonatomic)UILabel *durationLabel;

@property (strong, nonatomic)UIView *volumeView;
@property (strong, nonatomic)UISlider *volumeSlider;

@property (strong, nonatomic)UIView *overlayView;
@property (strong, nonatomic)UIView *videoBackgroundView;
@property (strong, nonatomic)UITapGestureRecognizer *signelTap;
@property (strong, nonatomic)UILabel *videoStatusLabel;

@property (strong, nonatomic)DWMoviePlayerController  *player;
@property (strong, nonatomic)NSDictionary *playUrls;
@property (strong, nonatomic)NSDictionary *currentPlayUrl;
@property (assign, nonatomic)NSTimeInterval historyPlaybackTime;

@property (strong, nonatomic)NSTimer *timer;

@property (assign, nonatomic)BOOL hiddenAll;
@property (assign, nonatomic)NSInteger hiddenDelaySeconds;
@property (assign, nonatomic)BOOL isfirst;
@property (assign, nonatomic)NSInteger downloadedSize;
@property (assign, nonatomic)DWDownloadItem *ditem;

@property(nonatomic,strong)NSDictionary *playPosition;
@end

@implementation LBModuleCCVideo
static   DWDrmServer *drmServer;
static NSMutableArray *array;
+ (void)launch {
    //在module.json里面配置的launchClassMethod，必须为类方法，引擎会在应用启动时调用配置的方法，模块可以在其中做一些初始化操作
    // 启动 drmServer
    drmServer = [[DWDrmServer alloc] initWithListenPort:21521];
    BOOL success = [drmServer start];
    if (!success) {
        //logerror(@"drmServer 启动失败");
    }
    array =[[NSMutableArray alloc] init];
}
+ (NSString*)dictionaryToJson:(NSDictionary *)dic
{
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}


- (id)initWithUZWebView:(UZWebView *)webView_ {
    if (self = [super initWithUZWebView:webView_]) {
        NSDictionary *feature = [self getFeatureByName:@"lbbVideo"];
        userId = [feature stringValueForKey:@"UserId" defaultValue:nil];
        apiKey = [feature stringValueForKey:@"apiKey" defaultValue:nil];
    }
    return self;
}
- (void)init:(NSDictionary *)paramDict{
    BOOL success = [drmServer start];
    if (!success) {
        logerror(@"drmServer 启动失败");
    }else{
        logerror(@"drmServer 启动sucess");
    }
}

- (void)dispose {
    //do clean
    // 停止 drmServer
    //[drmServer stop];
    
}

- (void)open:(NSDictionary *)paramDict{
    userId = [paramDict stringValueForKey:@"UserId" defaultValue:nil];
    apiKey = [paramDict stringValueForKey:@"apiKey" defaultValue:nil];
    definition =[paramDict integerValueForKey:@"definition" defaultValue:1];
    isEncryption =[paramDict integerValueForKey:@"isEncryption" defaultValue:0];
    self.isfirst = TRUE;
    self.player = [[DWMoviePlayerController alloc] initWithUserId:userId key:apiKey];
    self.player.currentPlaybackRate = 1;
    
    [self addObserverForMPMoviePlayController];
    [self removeTimer];
    [self addTimer];
    
    _cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    // 设置 DWMoviePlayerController 的 drmServerPort 用于drm加密视频的播放
    self.player.drmServerPort = drmServer.listenPort;  //DWAPPDELEGATE.drmServer.listenPort;  lbbniu
    
    viewx = [paramDict floatValueForKey:@"x" defaultValue:0];
    viewy = [paramDict floatValueForKey:@"y" defaultValue:20];
    float mainScreenWidth = [UIScreen mainScreen].bounds.size.width;
    float mainScreenHeight = [UIScreen mainScreen].bounds.size.height - 20;
    viewwidth = mainScreenWidth;//[paramDict floatValueForKey:@"w" defaultValue:mainScreenWidth];
    viewheight = mainScreenHeight;//[paramDict floatValueForKey:@"h" defaultValue:mainScreenHeight-viewy];
    
    title = [paramDict stringValueForKey:@"title" defaultValue:nil];//视频id
    self.videoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];//视频id
    self.videoLocalPath = [paramDict stringValueForKey:@"videoLocalPath" defaultValue:nil];//视频本地地址
    
    
    NSString * viewName = [paramDict stringValueForKey:@"fixedOn" defaultValue:nil];
    BOOL fixed = [paramDict boolValueForKey:@"fixed" defaultValue:YES];
    // 加载所需视图
    
    // 加载播放器 必须第一个加载
    [self loadPlayer:viewName fixed:fixed];
    
    // 加载播放器覆盖视图，它作为所有空间的父视图。
    self.overlayView = [[UIView alloc] initWithFrame:CGRectMake(viewx, viewy, viewwidth,viewheight)];
    self.overlayView.backgroundColor = [UIColor clearColor];
    
    [self addSubview:self.overlayView fixedOn:viewName fixed:fixed];
    
    
    [self loadHeaderView];
    [self loadFooterView];
    //[self loadVolumeView];
    [self loadVideoStatusLabel];
    
    self.signelTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSignelTap:)];
    self.signelTap.numberOfTapsRequired = 1;
    self.signelTap.delegate = self;
    [self.overlayView addGestureRecognizer:self.signelTap];
    
    
    // 开始下载
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSArray *cpaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cdocumentDirectory = [cpaths objectAtIndex:0];
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    BOOL isLocalPlay = [paramDict boolValueForKey:@"isFinish" defaultValue:NO];

    
    if (isLocalPlay) {
        NSString *videoPath;
        NSString *cvideoPath;
        if(isEncryption==1){//加密视频
            videoPath = [NSString stringWithFormat:@"%@/%@.mp4", documentDirectory, self.videoId];
            cvideoPath = [NSString stringWithFormat:@"%@/%@.mp4", cdocumentDirectory, self.videoId];
            NSString *tmpPath = [NSString stringWithFormat:@"%@/%@.pcm", documentDirectory, self.videoId];
            NSString *ctmpPath = [NSString stringWithFormat:@"%@/%@.pcm", cdocumentDirectory, self.videoId];
            if ([fileMgr fileExistsAtPath:tmpPath]) {
                self.videoId = nil;
                self.videoLocalPath =tmpPath;
            }else if([fileMgr fileExistsAtPath:ctmpPath]){
                self.videoId = nil;
                self.videoLocalPath =ctmpPath;
            }
        }else{
            videoPath = [NSString stringWithFormat:@"%@/%@.mp4", documentDirectory, self.videoId];
            cvideoPath = [NSString stringWithFormat:@"%@/%@.mp4", cdocumentDirectory, self.videoId];
        }
        
        
        BOOL bRet = [fileMgr fileExistsAtPath:videoPath];
        if (bRet) {
            self.videoId = nil;
            self.videoLocalPath =videoPath;
        }else if([fileMgr fileExistsAtPath:cvideoPath]){
            self.videoId = nil;
            self.videoLocalPath =cvideoPath;
        }
    }
    
    if (self.videoId) {
        // 获取videoId的播放url
        [self loadPlayUrls];
        
    } else if (self.videoLocalPath) {
        // 播放本地视频
        [self playLocalVideo];
        
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示"
                                                        message:@"没有可以播放的视频"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil, nil];
        [alert show];
    }
    // 10 秒后隐藏所有窗口
    self.hiddenDelaySeconds = 10;
}
//暂停播放
- (void)stop:(NSDictionary *)paramDict{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    self.hiddenDelaySeconds = 5;
    
    if (!self.playUrls || self.playUrls.count == 0) {
        [self loadPlayUrls];
        return;
    }
    
    UIImage *image = nil;
    //if (self.player.playbackState == MPMoviePlaybackStatePlaying) {
        // 暂停播放
        image = [UIImage imageNamed:@"res_lbbVideo/play-playbutton"];
        [self.player pause];
        [self.playbackButton setImage:image forState:UIControlStateNormal];
    //}
    
    if (cbId >= 0) {
        NSDictionary *ret = @{@"btnType":@"stop",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
    }
    
}
//关闭播放器
- (void)close:(NSDictionary *)paramDict{
    [self.player cancelRequestPlayInfo];
    [self saveNsUserDefaults];
    self.player.currentPlaybackTime = self.player.duration;
    self.player.contentURL = nil;
    [self.player stop];
    self.player = nil;
    [self removeAllObserver];
    [self removeTimer];
    // 显示 状态栏  quanping
    //[[UIApplication sharedApplication] setStatusBarHidden:NO];
    //[self.navigationController popViewControllerAnimated:YES];
    [self.videoBackgroundView removeFromSuperview];
    [self.overlayView removeFromSuperview];
}
//开始播放
- (void)start:(NSDictionary *)paramDict{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    self.hiddenDelaySeconds = 5;
    
    if (!self.playUrls || self.playUrls.count == 0) {
        [self loadPlayUrls];
        return;
    }
    
    UIImage *image = nil;
    //if (self.player.playbackState != MPMoviePlaybackStatePlaying) {
        // 继续播放
        image = [UIImage imageNamed:@"res_lbbVideo/player-pausebutton"];
        [self.player play];
        [self.playbackButton setImage:image forState:UIControlStateNormal];
    //}
    if (cbId >= 0) {
        NSDictionary *ret = @{@"btnType":@"start",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
    }
    
}
//跳到指定位置播放
- (void)seekTo:(NSDictionary *)paramDict{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    NSInteger  totime = [paramDict integerValueForKey:@"totime" defaultValue:0];
    if(totime >= 0 && totime<= self.player.duration){
        self.player.currentPlaybackTime = totime;
        self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:self.player.currentPlaybackTime];
        self.durationLabel.text = [DWTools formatSecondsToString:self.player.duration];
        self.duration_CurrentPlaybackTimeLabel.text = [NSString stringWithFormat:@"%@/%@",self.currentPlaybackTimeLabel.text, self.durationLabel.text];
        self.durationSlider.value = self.player.currentPlaybackTime;
        
        self.historyPlaybackTime = self.player.currentPlaybackTime;
    }
    if (cbId >= 0) {
        NSDictionary *ret = @{@"status":@"1",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
    }
}

- (void)download:(NSDictionary *)paramDict{
    __block LBModuleCCVideo  *that  = self;
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    NSString *videoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];//视频id
    if (!videoId) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示"
            message:@"videoId不能为空"
            delegate:nil
            cancelButtonTitle:@"OK"
            otherButtonTitles:nil, nil];
        [alert show];
        NSDictionary *ret = @{@"videoId":videoId,@"status":@"0",@"progress":@"0"};
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:NO];
        return;
    }
    // 开始下载
    //NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    userId = [paramDict stringValueForKey:@"UserId" defaultValue:nil];
    apiKey = [paramDict stringValueForKey:@"apiKey" defaultValue:nil];
    NSInteger  isDEncryption = [paramDict integerValueForKey:@"isEncryption" defaultValue:0];
    NSString *videoPath;
    if(isDEncryption==0){//不加密
        videoPath = [NSString stringWithFormat:@"%@/%@.mp4", documentDirectory, videoId];
    }else{//加密账号
        videoPath = [NSString stringWithFormat:@"%@/%@.pcm", documentDirectory, videoId];
    }
    //一个视频id被多次连续调用下载，不处理，直接返回
    if([videoId isEqualToString:self.downloadVideoId] && (self.ditem.videoDownloadStatus==DWDownloadStatusStart || self.ditem.videoDownloadStatus==DWDownloadStatusDownloading)){
        logdebug(@"============= %@", @"lbbniu");
        return;
    }
    
    if(downloader != nil){
        //切换视频下载文件时候，前一个视频文件并没有真正的开始下载，而是还在获取下载信息过程中
        //这个时候不能切换下载视频文件，防止多个进程下载同一个视频文件
        if(self.ditem.videoDownloadStatus == DWDownloadStatusStart){
            NSDictionary *ret = @{@"videoId":videoId,@"status":@"2",@"progress":@"0",@"result":@"系统繁忙无法切换视频下载"};
            [that sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
            logdebug(@"系统繁忙无法切换视频下载 %@", @"lbbniu");
            return;
        }
        [downloader pause];
        self.ditem.videoDownloadStatus = DWDownloadStatusPause;
    }
    downloader = nil;
    for(DWDownloadItem *item in array){
        if([videoId isEqualToString:item.videoId]){
            //logerror(@"downloader == pause %@", videoPath);
            downloader = item.downloader;
            self.ditem = item;
            break;
        }
    }
    
    
    if(downloader == nil){
        logerror(@"downloader == nil %@", videoPath);
        DWDownloadItem *item = [[DWDownloadItem alloc] initWithVideoId:videoId];
        item.downloader = [[DWDownloader alloc] initWithUserId:userId
                                               andVideoId:videoId
                                                      key:apiKey
                                          destinationPath:videoPath];
        
        downloader=item.downloader;
        item.time =  [[NSDate date] timeIntervalSince1970];
        self.ditem = item;
        [array insertObject:item atIndex:0];
    }/*else{
    
        self.downloadVideoId = videoId;
        //[self.ditem.downloader start];
        //[self.ditem.downloader pause];
        [self.ditem.downloader resume];
        self.ditem.videoDownloadStatus = DWDownloadStatusDownloading;
        return;
    }*/
    
    
    /*
    if(downloader == nil){
        logerror(@"downloader == nil %@", videoPath);
        downloader = [[DWDownloader alloc] initWithUserId:userId
                                                    andVideoId:videoId
                                                           key:apiKey
                                               destinationPath:videoPath];
    }else{
        logerror(@"downloader == pause %@", videoPath);
        if([videoId isEqualToString:self.downloadVideoId]){
            return;
        }
        [downloader pause];
        downloader = nil;
        downloader = [[DWDownloader alloc] initWithUserId:userId
                                                    andVideoId:videoId
                                                           key:apiKey
                                               destinationPath:videoPath];
    }*/
    self.downloadVideoId = videoId;
    self.progress = @"0";

    self.ditem.downloader.timeoutSeconds = 10;
    //logerror(@"download progressBlock %@", @"lbbniu");
    self.ditem.downloader.progressBlock = ^(float progress, NSInteger totalBytesWritten, NSInteger totalBytesExpectedToWrite){
        
        that.ditem.videoDownloadStatus = DWDownloadStatusDownloading;
        that.downloadedSize = totalBytesWritten;
        if(that.ditem.downloader.remoteFileSize < 2000){
            [that rmFile:that.downloadVideoId];
            return;
        }
        if (cbId >= 0) {
            //logerror(@"download progressBlock %@", [NSString stringWithFormat:@"%ld" ,(long)totalBytesWritten]);
            float downloadedSizeMB = totalBytesWritten/1024.0/1024.0;
            float fileSizeMB = downloader.remoteFileSize/1024.0/1024.0;
            float videoDownloadProgress =(float)(downloadedSizeMB/fileSizeMB*100);
            
            NSString *progre =[NSString stringWithFormat:@"%0.0f" ,videoDownloadProgress];
            //if(videoDownloadProgress>0 && that.progress !=videoDownloadProgress){
            if(videoDownloadProgress>0 && true != [progre isEqualToString:that.progress]){
                //that.progress =videoDownloadProgress;
                that.progress =  progre;
                logdebug(@"progressBlock-%@----------%@",that.downloadVideoId,progre);
                NSDictionary *ret = @{@"videoId":videoId,@"status":@"1",@"progress":progre,@"finish":@"NO"};
                [that sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:NO];
            }
        }else{
            //logerror(@"download progressBlock %@", @"lbbniu");
        }

    };
    
    self.ditem.downloader.failBlock = ^(NSError *error) {
        that.ditem.time -= 7200;
        logdebug(@"================failBlock====================");
        if(that.ditem.downloader.remoteFileSize == -1){
            logdebug(@"download fail-%@----------%@",that.downloadVideoId,[error localizedDescription]);
            NSDictionary *ret = @{@"videoId":videoId,@"status":@"3",@"progress":@"0",@"result":[error localizedDescription]};
            [that sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:NO];
        }
        if(that.ditem.downloader.remoteFileSize < 2000){
            that.progress = @"0";
            [that rmFile:that.downloadVideoId];
        }
        if(that.ditem.count<=3){
            that.ditem.count = that.ditem.count +1;
            [that.ditem.downloader start];
            return;
        }
        if (cbId >= 0) {
            logdebug(@"================111111111111====================");
            that.ditem.videoDownloadStatus = DWDownloadStatusFail;
            NSDictionary *ret = @{@"videoId":videoId,@"status":@"0",@"progress":@"0",@"result":[error localizedDescription]};
            [that sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
        }
    };
    
    self.ditem.downloader.finishBlock = ^() {
        if (cbId >= 0) {
            NSDictionary *ret = @{@"videoId":videoId,@"progress":@"100",@"result":@"下载完成",@"status":@"1",@"finish":@"YES"};
            that.ditem.videoDownloadStatus = DWDownloadStatusFinish;
            [that sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
        }
    };

    if(downloader != nil&&self.ditem.videoDownloadStatus == DWDownloadStatusFinish){
        if (cbId >= 0) {
            NSDictionary *ret = @{@"videoId":videoId,@"progress":@"100",@"result":@"下载完成",@"status":@"1",@"finish":@"YES"};
            [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
        }
        return;
    }
    if(downloader != nil&&self.ditem.videoDownloadStatus == DWDownloadStatusPause){
        if([[NSDate date] timeIntervalSince1970] - self.ditem.time < 6000){
            [downloader resume];
            self.ditem.videoDownloadStatus = DWDownloadStatusStart;
            logerror(@"download %@－－－－resume－－－－ %@", self.downloadVideoId,@"DWDownloadStatusDownloading");
            return;
        }
    }
    self.ditem.time =[[NSDate date] timeIntervalSince1970];
    [self.ditem.downloader start];
    self.ditem.count = 1;
    logerror(@"----------------- %@", @"lbbniu");
    //[self.ditem.downloader startWithUrlString:@"http://bm1.31.play.bokecc.com/flvs/ca/QxhMN/urniS3IgwN-10.mp4?t=1470146526&key=66600CF7032E1BA1B32CBA5DA9027A0E"];
    self.ditem.videoDownloadStatus = DWDownloadStatusStart;
}
- (void)downloadStop:(NSDictionary *)paramDict{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    if (downloader && self.ditem.videoDownloadStatus!=DWDownloadStatusStart) {
        [self.ditem.downloader pause];
        self.ditem.videoDownloadStatus = DWDownloadStatusPause;
        logerror(@"download lbbniu %@----%@", @"downloadStop",self.downloadVideoId);
        if (cbId >= 0) {
            NSDictionary *ret = @{@"status":@"1"};
            [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
            return;
        }
    }
    if (cbId >= 0) {
        NSDictionary *ret;
        if(downloader == nil){
            ret = @{@"status":@"1"};
        }else{
            ret = @{@"status":@"0"};
        }
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
    }
}
- (void)downloadStart:(NSDictionary *)paramDict{
    NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    if (downloader) {
        logerror(@"download progressBlock %@", @"downloadStart");
        [self.ditem.downloader resume];
        self.ditem.videoDownloadStatus = DWDownloadStatusDownloading;
    }
    if (cbId >= 0) {
        NSDictionary *ret = @{@"status":@"1"};
        [self sendResultEventWithCallbackId:cbId dataDict:ret errDict:nil doDelete:YES];
    }
}
- (void)rmVideo:(NSDictionary *)paramDict{
    //NSInteger  cbId = [paramDict integerValueForKey:@"cbId" defaultValue:-1];
    NSString *videoId = [paramDict stringValueForKey:@"videoId" defaultValue:nil];//视频id
    if (!videoId) {
        return;
    }
    [self rmFile:videoId];
}
- (void)rmFile:(NSString *)videoId{
    if (!videoId) {
        return;
    }
    //document目录
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths objectAtIndex:0];
    NSString *videoPath;
    NSError *err;
    videoPath = [NSString stringWithFormat:@"%@/%@.pcm", documentDirectory, videoId];
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    BOOL bRet = [fileMgr fileExistsAtPath:videoPath];
    if (bRet) {
        [fileMgr removeItemAtPath:videoPath error:&err];
    }
    videoPath = [NSString stringWithFormat:@"%@/%@.mp4", documentDirectory, videoId];
    bRet = [fileMgr fileExistsAtPath:videoPath];
    if (bRet) {
        [fileMgr removeItemAtPath:videoPath error:&err];
    }
    //caches目录
    paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    documentDirectory = [paths objectAtIndex:0];
    videoPath = [NSString stringWithFormat:@"%@/%@.pcm", documentDirectory, videoId];
    bRet = [fileMgr fileExistsAtPath:videoPath];
    if (bRet) {
        [fileMgr removeItemAtPath:videoPath error:&err];
    }
    videoPath = [NSString stringWithFormat:@"%@/%@.mp4", documentDirectory, videoId];
    bRet = [fileMgr fileExistsAtPath:videoPath];
    if (bRet) {
        [fileMgr removeItemAtPath:videoPath error:&err];
    }
}


//===============================================================================================================
//不公开的方法定义
# pragma mark - 音量
- (void)loadVolumeView
{
    CGRect frame = CGRectZero;
    frame.origin.x = 16;
    frame.origin.y = self.headerView.frame.origin.y + self.headerView.frame.size.height + 22;
    frame.size.width = 30;
    frame.size.height = 170;
    
    self.volumeView = [[UIView alloc] initWithFrame:frame];
    self.volumeView.alpha = 0.5;
    [self.overlayView addSubview:self.volumeView];
    //logdebug(@"self.volumeView frame: %@", NSStringFromCGRect(self.volumeView.frame));
    
    frame = CGRectZero;
    frame.origin.x = 0;
    frame.origin.y = 0;
    frame.size.width = self.volumeView.frame.size.width;
    frame.size.height = self.volumeView.frame.size.height;
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:frame];
    imageView.image = [UIImage imageNamed:@"res_lbbVideo/player-volume-box"];
    [self.volumeView addSubview:imageView];
    
    
    self.volumeSlider = [[UISlider alloc] init];
    self.volumeSlider.transform = CGAffineTransformMakeRotation(-M_PI/2);
    
    frame = CGRectZero;
    frame.origin.x = self.volumeView.frame.origin.x;
    frame.origin.y = self.volumeView.frame.origin.y + 10;
    frame.size.width = 30;
    frame.size.height = 140;
    self.volumeSlider.frame = frame;
    
    self.volumeSlider.minimumValue = 0;
    self.volumeSlider.maximumValue = 1.0;
    //lbbniu   self.volumeSlider.value = [MPMusicPlayerController applicationMusicPlayer].volume;
    [self.volumeSlider setMaximumTrackImage:[UIImage imageNamed:@"res_lbbVideo/player-slider-inactive"]
                                   forState:UIControlStateNormal];
    [self.volumeSlider setMinimumTrackImage:[UIImage imageNamed:@"res_lbbVideo/player-slider-active"]
                                   forState:UIControlStateNormal];
    [self.volumeSlider setThumbImage:[UIImage imageNamed:@"res_lbbVideo/player-slider-handle"]
                            forState:UIControlStateNormal];
    
    [self.volumeSlider addTarget:self action:@selector(volumeSliderMoved:) forControlEvents:UIControlEventValueChanged];
    [self.volumeSlider addTarget:self action:@selector(volumeSliderTouchDone:) forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.volumeSlider];
    
    //logdebug(@"self.volumeSlider frame: %@", NSStringFromCGRect(self.volumeSlider.frame));
}
- (void)volumeSliderMoved:(UISlider *)slider
{
    [MPMusicPlayerController applicationMusicPlayer].volume = slider.value;
}

- (void)volumeSliderTouchDone:(UISlider *)slider
{
}
# pragma mark - 手势识别 UIGestureRecognizerDelegate
-(void)handleSignelTap:(UIGestureRecognizer*)gestureRecognizer
{
    if (self.hiddenAll) {
        [self showBasicViews];
        self.hiddenDelaySeconds = 5;
        
    } else {
        [self hiddenAllView];
        self.hiddenDelaySeconds = 0;
    }
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event{
  

}

# pragma mark - 加载播放器
- (void)loadPlayer:(NSString *)viewName fixed:(BOOL)fixed
{
    self.videoBackgroundView = [[UIView alloc] init];
    
    self.videoBackgroundView.frame = CGRectMake(viewx, viewy, viewwidth,viewheight);
    
    self.videoBackgroundView.backgroundColor = [UIColor blackColor];//[UIColor blackColor];
    //[self.view addSubview:self.videoBackgroundView];
    [self addSubview:self.videoBackgroundView fixedOn:viewName fixed:fixed];
    
    self.player.scalingMode = MPMovieScalingModeAspectFit;
    self.player.controlStyle = MPMovieControlStyleNone;
    self.player.view.backgroundColor = [UIColor clearColor];
    self.player.view.frame = self.videoBackgroundView.bounds;
    
    [self.videoBackgroundView addSubview:self.player.view];
}

# pragma mark - 播放视频
- (void)loadPlayUrls
{
    self.player.videoId = self.videoId;
    self.player.timeoutSeconds = 10;
    
    __weak LBModuleCCVideo *blockSelf = self;
    self.player.failBlock = ^(NSError *error) {
        blockSelf.videoStatusLabel.hidden = NO;
        blockSelf.videoStatusLabel.text = @"加载失败";
    };
    
    self.player.getPlayUrlsBlock = ^(NSDictionary *playUrls) {
        // [必须]判断 status 的状态，不为"0"说明该视频不可播放，可能正处于转码、审核等状态。
        NSNumber *status = [playUrls objectForKey:@"status"];
        if (status == nil || [status integerValue] != 0) {
            NSString *message = [NSString stringWithFormat:@"%@ %@:%@",
                                 blockSelf.videoId,
                                 [playUrls objectForKey:@"status"],
                                 [playUrls objectForKey:@"statusinfo"]];
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示"
                                                            message:message
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil, nil];
            [alert show];
            return;
        }
        
        blockSelf.playUrls = playUrls;
        
        [blockSelf resetViewContent];
    };
    
    [self.player startRequestPlayInfo];
}

# pragma mark - 根据播放url更新涉及的视图

- (void)resetViewContent
{
    // 获取默认清晰度播放url
    NSNumber *defaultquality = [self.playUrls objectForKey:@"defaultquality"];
    if(definition == 1){
        defaultquality = [NSNumber numberWithInteger:10];
    }else{
        defaultquality = [NSNumber numberWithInteger:20];
    }
    for (NSDictionary *playurl in [self.playUrls objectForKey:@"qualities"]) {
        if (defaultquality == [playurl objectForKey:@"quality"]) {
            self.currentPlayUrl = playurl;
            break;
        }
    }
    
    if (!self.currentPlayUrl) {
        self.currentPlayUrl = [[self.playUrls objectForKey:@"qualities"] objectAtIndex:0];
    }
    
    
    [self.player prepareToPlay];
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    [self.player play];
    
}
# pragma mark - headerView
- (void)loadHeaderView
{
    //全屏
    //self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 20,self.overlayView.frame.size.width, 38)];
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0,self.overlayView.frame.size.width, 38)];
    self.headerView.backgroundColor = [UIColor colorWithRed:33/255.0 green:41/255.0 blue:43/255.0 alpha:1];
    [self.overlayView addSubview:self.headerView];
    /**
     *  NOTE: 由于各个view之间的坐标有依赖关系，所以以下view的加载顺序必须为：
     *  qualityView -> subtitleView -> backButton
     */
    
    if (self.videoId) {
        // 清晰度   右上角按钮，不是清晰度，回调按钮
        [self loadQualityView];
        
    }
    
    // 返回按钮及视频标题
    [self loadBackButton];
}

# pragma mark 清晰度   右上角按钮，不是清晰度，回调按钮
- (void)loadQualityView
{
    self.qualityButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    
    CGRect frame = CGRectZero;
    frame.origin.x = self.headerView.frame.size.width - 70;
    frame.origin.y = self.headerView.frame.origin.y + 9;
    frame.size.width = 50;
    frame.size.height = 20;
    self.qualityButton.frame = frame;
    
    self.qualityButton.backgroundColor = [UIColor clearColor];
    [self.qualityButton setBackgroundImage:[UIImage imageNamed:@"res_lbbVideo/player_select"] forState:UIControlStateNormal];
    [self.qualityButton addTarget:self action:@selector(qualityButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.overlayView addSubview:self.qualityButton];
}
- (void)qualityButtonAction:(UIButton *)button
{
    if (_cbId >= 0) {
        NSDictionary *ret = @{@"btnType":@"2"};
        [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
    }
}
# pragma mark 返回按钮及视频标题
- (void)loadBackButton
{
    self.backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    
    CGRect frame;
    frame.origin.x = 15;
    frame.origin.y = self.headerView.frame.origin.y + 4;
    frame.size.width = self.headerView.frame.size.width-100;//300;
    frame.size.height = 30;
    self.backButton.frame = frame;
    
    self.backButton.backgroundColor = [UIColor clearColor];
    [self.backButton setTitle:title forState:UIControlStateNormal];
    [self.backButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.backButton setImage:[UIImage imageNamed:@"res_lbbVideo/player-back-button"] forState:UIControlStateNormal];
    self.backButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.backButton addTarget:self action:@selector(backButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.backButton];
    
}
- (void)backButtonAction:(UIButton *)button
{
    if (_cbId >= 0) {
        NSDictionary *ret = @{@"btnType":@"1",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
    }
    [self.player cancelRequestPlayInfo];
    [self saveNsUserDefaults];
    self.player.currentPlaybackTime = self.player.duration;
    self.player.contentURL = nil;
    [self.player stop];
    self.player = nil;
    [self removeAllObserver];
    [self removeTimer];
    // 显示 状态栏  quanping
    //[[UIApplication sharedApplication] setStatusBarHidden:NO];
    //[self.navigationController popViewControllerAnimated:YES];
    [self.videoBackgroundView removeFromSuperview];
    [self.overlayView removeFromSuperview];
}
- (void)loadFooterView
{
    self.footerView = [[UIView alloc] initWithFrame:CGRectMake(0, self.overlayView.frame.size.height-40, self.overlayView.frame.size.width, 40)];
    self.footerView.backgroundColor = [UIColor colorWithWhite:31/255.0f alpha:1];
    [self.overlayView addSubview:self.footerView];
    
    
    /**
     *  NOTE: 由于各个view之间的坐标有依赖关系，所以以下view的加载顺序必须为：
     *  playbackButton -> currentPlaybackTimeLabel -> screenSizeView  -> durationLabel -> playbakSlider
     */
    
    // 播放按钮
    [self loadPlaybackButton];
    
    // 当前播放时间    视频总时间
    [self loadDurationCurrentPlaybackTimeLabel];
    // 当前播放时间
    [self loadCurrentPlaybackTimeLabel];
    
    // 画面尺寸
    //[self loadScreenSizeView];
    
    // 视频总时间
    [self loadDurationLabel];
    
    
    //加载 倍率  声音 笔记 提问 讲义
    [self loadActionFiveBtn];
    
    // 时间滑动条
    [self loadPlaybackSlider];
}
# pragma mark 上一节  播放按钮  下一节
- (void)loadPlaybackButton
{
    //上一节按钮
    self.playpreButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect frame_pre = CGRectZero;
    frame_pre.origin.x = self.footerView.frame.origin.x + 10;
    frame_pre.origin.y = self.footerView.frame.origin.y + 5;
    frame_pre.size.width = 25;
    frame_pre.size.height = 30;
    self.playpreButton.frame = frame_pre;
    [self.playpreButton setImage:[UIImage imageNamed:@"res_lbbVideo/player-pre"] forState:UIControlStateNormal];
    [self.playpreButton addTarget:self action:@selector(playpreButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.playpreButton];
    
    //播放按钮
    self.playbackButton = [UIButton buttonWithType:UIButtonTypeCustom];
    
    CGRect frame_back = CGRectZero;
    frame_back.origin.x = self.playpreButton.frame.origin.x + self.playpreButton.frame.size.width+10;
    frame_back.origin.y = self.footerView.frame.origin.y + 5;
    frame_back.size.width = 25;
    frame_back.size.height = 30;
    self.playbackButton.frame = frame_back;
    
    [self.playbackButton setImage:[UIImage imageNamed:@"res_lbbVideo/play-playbutton"] forState:UIControlStateNormal];
    [self.playbackButton addTarget:self action:@selector(playbackButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.playbackButton];
    
    //上一节按钮
    self.playnextButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect frame_next = CGRectZero;
    frame_next.origin.x = self.playbackButton.frame.origin.x + self.playbackButton.frame.size.width+10;
    frame_next.origin.y = self.footerView.frame.origin.y + 5;
    frame_next.size.width = 25;
    frame_next.size.height = 30;
    self.playnextButton.frame = frame_next;
    [self.playnextButton setImage:[UIImage imageNamed:@"res_lbbVideo/player-next"] forState:UIControlStateNormal];
    [self.playnextButton addTarget:self action:@selector(playnextButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.playnextButton];
    
}
-(void)loadActionFiveBtn
{
    //讲义
    self.playjiangyiButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect frame_jiangyi;
    frame_jiangyi.origin.x = self.footerView.frame.size.width-10-50;
    frame_jiangyi.origin.y = self.footerView.frame.origin.y + 5;
    frame_jiangyi.size.width = 50;//300;
    frame_jiangyi.size.height = 30;
    self.playjiangyiButton.frame = frame_jiangyi;
    [self.playjiangyiButton setTitle:@" 讲义" forState:UIControlStateNormal];
    [self.playjiangyiButton setTitleColor:[UIColor colorWithWhite:124/255.0f alpha:1] forState:UIControlStateNormal];
    self.playjiangyiButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.playjiangyiButton setImage:[UIImage imageNamed:@"res_lbbVideo/player_jiangyi"] forState:UIControlStateNormal];
    self.playjiangyiButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.playjiangyiButton addTarget:self action:@selector(jiangyiButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.playjiangyiButton];
    
    //提问
    self.playtiwenButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect frame_tiwen;
    frame_tiwen.origin.x = self.playjiangyiButton.frame.origin.x-10-54;
    frame_tiwen.origin.y = self.footerView.frame.origin.y + 5;
    frame_tiwen.size.width = 54;//300;
    frame_tiwen.size.height = 30;
    self.playtiwenButton.frame = frame_tiwen;
    [self.playtiwenButton setTitle:@" 提问" forState:UIControlStateNormal];
    [self.playtiwenButton setTitleColor:[UIColor colorWithWhite:124/255.0f alpha:1] forState:UIControlStateNormal];
    self.playtiwenButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.playtiwenButton setImage:[UIImage imageNamed:@"res_lbbVideo/player_tiwen"] forState:UIControlStateNormal];
    self.playtiwenButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.playtiwenButton addTarget:self action:@selector(tiwenButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.playtiwenButton];
    
    //笔记
    self.playbijiButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect frame_biji;
    frame_biji.origin.x = self.playtiwenButton.frame.origin.x-10-50;
    frame_biji.origin.y = self.footerView.frame.origin.y + 5;
    frame_biji.size.width = 50;//300;
    frame_biji.size.height = 30;
    self.playbijiButton.frame = frame_biji;
    [self.playbijiButton setTitle:@" 笔记" forState:UIControlStateNormal];
    [self.playbijiButton setTitleColor:[UIColor colorWithWhite:124/255.0f alpha:1] forState:UIControlStateNormal];
    self.playbijiButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.playbijiButton setImage:[UIImage imageNamed:@"res_lbbVideo/player_biji"] forState:UIControlStateNormal];
    self.playbijiButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [self.playbijiButton addTarget:self action:@selector(bijiButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.playbijiButton];
    
    //声音
    self.playvolumeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect frame_volume;
    frame_volume.origin.x = self.playbijiButton.frame.origin.x-20-25;
    frame_volume.origin.y = self.footerView.frame.origin.y + 5;
    frame_volume.size.width = 25;//300;
    frame_volume.size.height = 30;
    self.playvolumeButton.frame = frame_volume;
    [self.playvolumeButton setImage:[UIImage imageNamed:@"res_lbbVideo/player_volume"] forState:UIControlStateNormal];
    [self.playvolumeButton addTarget:self action:@selector(volumeButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    //[self.overlayView addSubview:self.playvolumeButton];
    
    //倍率按钮
    self.playbeilvButton = [UIButton buttonWithType:UIButtonTypeCustom];
    CGRect frame;
    
    //frame.origin.x = self.playvolumeButton.frame.origin.x-10-39;
    //frame.origin.y = self.footerView.frame.origin.y + 5;
    frame.origin.x = self.playbijiButton.frame.origin.x-20-25;
    frame.origin.y = self.footerView.frame.origin.y + 5;
    frame.size.width = 39;//300;
    frame.size.height = 30;
    self.playbeilvButton.frame = frame;
    [self.playbeilvButton setImage:[UIImage imageNamed:@"res_lbbVideo/lbb_sudu10x"] forState:UIControlStateNormal];
    [self.playbeilvButton addTarget:self action:@selector(beilvButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.playbeilvButton];

    
}
- (void)playbackButtonAction:(UIButton *)button
{
    self.hiddenDelaySeconds = 5;
    
    if (!self.playUrls || self.playUrls.count == 0) {
        [self loadPlayUrls];
        return;
    }
    
    UIImage *image = nil;
    if (self.player.playbackState == MPMoviePlaybackStatePlaying) {
        // 暂停播放
        image = [UIImage imageNamed:@"res_lbbVideo/play-playbutton"];
        [self.player pause];
        
    } else {
        // 继续播放
        image = [UIImage imageNamed:@"res_lbbVideo/player-pausebutton"];
        [self.player play];
    }
    
    [self.playbackButton setImage:image forState:UIControlStateNormal];
    
    if (_cbId >= 0) {
        NSDictionary *ret = @{@"btnType":@"play",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
    }
    
}
- (void)playpreButtonAction:(UIButton *)button
{
    if (_cbId >= 0) {
        NSDictionary *ret = @{@"btnType":@"3",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
    }
    
}
- (void)playnextButtonAction:(UIButton *)button
{
    if (_cbId >= 0) {
        NSDictionary *ret = @{@"btnType":@"4",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
    }
    
}
- (void)beilvButtonAction:(UIButton *)button
{
    UIImage *image = nil;
    if(self.player.currentPlaybackRate == (float)1){
        self.player.currentPlaybackRate = 1.3;
        image = [UIImage imageNamed:@"res_lbbVideo/lbb_sudu13x"];
    }else if(self.player.currentPlaybackRate == (float)1.3){
        self.player.currentPlaybackRate = 1.6;
        image = [UIImage imageNamed:@"res_lbbVideo/lbb_sudu16x"];
    }else if(self.player.currentPlaybackRate == (float)1.6){
        self.player.currentPlaybackRate = 2;
        image = [UIImage imageNamed:@"res_lbbVideo/lbb_sudu20x"];
    }else if(self.player.currentPlaybackRate == (float)2){
        self.player.currentPlaybackRate = 1;
        image = [UIImage imageNamed:@"res_lbbVideo/lbb_sudu10x"];
    }else{
        self.player.currentPlaybackRate = 1;
        image = [UIImage imageNamed:@"res_lbbVideo/lbb_sudu10x"];
    }
    [self.playbeilvButton setImage:image forState:UIControlStateNormal];
    if (_cbId >= 0) {
        NSDictionary *ret = @{@"btnType":@"5",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
    }
}
- (void)volumeButtonAction:(UIButton *)button
{
    if (_cbId >= 0) {
        NSDictionary *ret = @{@"btnType":@"6",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
    }
}
- (void)bijiButtonAction:(UIButton *)button
{
    if (_cbId >= 0) {
        NSDictionary *ret = @{@"btnType":@"7",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
    }
}
- (void)tiwenButtonAction:(UIButton *)button
{
    if (_cbId >= 0) {
        NSDictionary *ret = @{@"btnType":@"8",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
    }
}
- (void)jiangyiButtonAction:(UIButton *)button
{
    if (_cbId >= 0) {
        NSDictionary *ret = @{@"btnType":@"9",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
        [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
    }
}

# pragma mark 当前播放时间和视频总时间
- (void)loadDurationCurrentPlaybackTimeLabel
{
    CGRect frame = CGRectZero;
    frame.origin.x = self.playnextButton.frame.origin.x + self.playnextButton.frame.size.width + 10;
    frame.origin.y = self.footerView.frame.origin.y + 10;
    frame.size.width = 90;
    frame.size.height = 20;
    
    self.duration_CurrentPlaybackTimeLabel = [[UILabel alloc] initWithFrame:frame];
    self.duration_CurrentPlaybackTimeLabel.text = @"00:00/00:00";
    self.duration_CurrentPlaybackTimeLabel.textColor = [UIColor whiteColor];
    self.duration_CurrentPlaybackTimeLabel.font = [UIFont systemFontOfSize:12];
    self.duration_CurrentPlaybackTimeLabel.backgroundColor = [UIColor clearColor];
    [self.overlayView addSubview:self.duration_CurrentPlaybackTimeLabel];
}



# pragma mark 当前播放时间
- (void)loadCurrentPlaybackTimeLabel
{
    CGRect frame = CGRectZero;
    frame.origin.x = self.playnextButton.frame.origin.x + self.playnextButton.frame.size.width + 10;
    frame.origin.y = self.footerView.frame.origin.y + 10;
    frame.size.width = 35;
    frame.size.height = 20;
    
    self.currentPlaybackTimeLabel = [[UILabel alloc] initWithFrame:frame];
    self.currentPlaybackTimeLabel.text = @"00:00";
    self.currentPlaybackTimeLabel.textColor = [UIColor whiteColor];
    self.currentPlaybackTimeLabel.font = [UIFont systemFontOfSize:12];
    self.currentPlaybackTimeLabel.backgroundColor = [UIColor clearColor];
    //[self.overlayView addSubview:self.currentPlaybackTimeLabel];
}
# pragma mark 视频总时间
- (void)loadDurationLabel
{
    CGRect frame = CGRectZero;
    frame.size.width = 35;
    frame.size.height = 20;
    frame.origin.x = self.currentPlaybackTimeLabel.frame.origin.x + self.currentPlaybackTimeLabel.frame.size.width;
    frame.origin.y = self.footerView.frame.origin.y + 10;
    
    self.durationLabel = [[UILabel alloc] initWithFrame:frame];
    self.durationLabel.text = @"00:00";
    self.durationLabel.textColor = [UIColor whiteColor];
    self.durationLabel.backgroundColor = [UIColor clearColor];
    self.durationLabel.font = [UIFont systemFontOfSize:12];
    
    //[self.overlayView addSubview:self.durationLabel];
}

# pragma mark 时间滑动条
- (void)loadPlaybackSlider
{
    CGRect frame = CGRectZero;
    frame.origin.x = -2;
    frame.origin.y = self.footerView.frame.origin.y-15;
    frame.size.width = self.footerView.frame.size.width+4;//self.durationLabel.frame.origin.x +145;
    frame.size.height = 30;
    
    self.durationSlider = [[UISlider alloc] initWithFrame:frame];
    self.durationSlider.value = 0.0f;
    self.durationSlider.minimumValue = 0.0f;
    self.durationSlider.maximumValue = 1.0f;
    [self.durationSlider setMaximumTrackImage:[UIImage imageNamed:@"res_lbbVideo/player-slider-inactive"]
                                     forState:UIControlStateNormal];
    [self.durationSlider setMinimumTrackImage:[UIImage imageNamed:@"res_lbbVideo/player-slider-active"]
                                     forState:UIControlStateNormal];
    [self.durationSlider setThumbImage:[UIImage imageNamed:@"res_lbbVideo/player-slider-handle"]
                              forState:UIControlStateNormal];
    [self.durationSlider addTarget:self action:@selector(durationSliderMoving:) forControlEvents:UIControlEventValueChanged];
    [self.durationSlider addTarget:self action:@selector(durationSliderDone:) forControlEvents:UIControlEventTouchUpInside];
    [self.overlayView addSubview:self.durationSlider];
    
}
- (void)durationSliderMoving:(UISlider *)slider
{
    
    if (self.player.playbackState != MPMoviePlaybackStatePaused) {
        [self.player pause];
    }
    self.player.currentPlaybackTime = slider.value;
    //[self saveNsUserDefaults];
    self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:self.player.currentPlaybackTime];
    self.duration_CurrentPlaybackTimeLabel.text = [NSString stringWithFormat:@"%@/%@",self.currentPlaybackTimeLabel.text, self.durationLabel.text];
    self.historyPlaybackTime = self.player.currentPlaybackTime;
}

- (void)durationSliderDone:(UISlider *)slider
{
    if (self.player.playbackState != MPMoviePlaybackStatePlaying) {
        [self.player play];
    }
    self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:self.player.currentPlaybackTime];
    self.duration_CurrentPlaybackTimeLabel.text = [NSString stringWithFormat:@"%@/%@",self.currentPlaybackTimeLabel.text, self.durationLabel.text];
    self.historyPlaybackTime = self.player.currentPlaybackTime;
}


- (void)resetPlayer
{
    self.player.contentURL = [NSURL URLWithString:[self.currentPlayUrl objectForKey:@"playurl"]];
    
    self.videoStatusLabel.hidden = NO;
    self.videoStatusLabel.text = @"正在加载...";
    
    [self.player prepareToPlay];
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    [self.player play];
}
# pragma mark - 播放本地文件

- (void)playLocalVideo
{
    self.playUrls = [NSDictionary dictionaryWithObject:self.videoLocalPath forKey:@"playurl"];
    self.player.contentURL = [[NSURL alloc] initFileURLWithPath:self.videoLocalPath];
    
    [self.player prepareToPlay];
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    [self.player play];
    logerror(@"play url: %@", self.player.originalContentURL);
}

# pragma mark - MPMoviePlayController Notifications
- (void)addObserverForMPMoviePlayController
{
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // MPMovieDurationAvailableNotification
    [notificationCenter addObserver:self selector:@selector(moviePlayerDurationAvailable) name:MPMovieDurationAvailableNotification object:self.player];
    
    // MPMovieNaturalSizeAvailableNotification
    
    // MPMoviePlayerLoadStateDidChangeNotification
    [notificationCenter addObserver:self selector:@selector(moviePlayerLoadStateDidChange) name:MPMoviePlayerLoadStateDidChangeNotification object:self.player];
    
    // MPMoviePlayerPlaybackDidFinishNotification
    [notificationCenter addObserver:self selector:@selector(moviePlayerPlaybackDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.player];
    
    // MPMoviePlayerPlaybackStateDidChangeNotification
    [notificationCenter addObserver:self selector:@selector(moviePlayerPlaybackStateDidChange) name:MPMoviePlayerPlaybackStateDidChangeNotification object:self.player];
    
    // MPMoviePlayerReadyForDisplayDidChangeNotification
}

- (void)moviePlayerDurationAvailable
{
    logdebug("MovieDurationAvailableNotification----------------Available");
    self.durationLabel.text = [DWTools formatSecondsToString:self.player.duration];
    self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:0];
    self.duration_CurrentPlaybackTimeLabel.text = [NSString stringWithFormat:@"%@/%@",self.currentPlaybackTimeLabel.text, self.durationLabel.text];
    self.durationSlider.minimumValue = 0.0;
    self.durationSlider.maximumValue = self.player.duration;
    //logdebug(@"seconds %f maximumValue %f %@", self.player.duration, self.durationSlider.maximumValue, self.durationLabel.text);
}
- (void)moviePlayerLoadStateDidChange
{
    logdebug("LoadStateDidChangeNotification----ssss------%lu",self.player.loadState);
    switch (self.player.loadState) {
        case MPMovieLoadStatePlayable://1
            // 可播放
            logdebug(@"%@ playable", self.player.originalContentURL);
            self.videoStatusLabel.hidden = YES;
            if (_videoId) {
                if (self.player.playNum < 2) {
                    [self readNSUserDefaults];
                    [self.player first_load];
                    self.player.playNum ++;
                }
            }
            break;
        case MPMovieLoadStatePlaythroughOK://2
            // 状态为缓冲几乎完成，可以连续播放
            logdebug(@"%@ PlaythroughOK", self.player.originalContentURL);
            self.videoStatusLabel.hidden = YES;
            if (_videoId) {
                if (self.player.playNum < 2) {
                    [self readNSUserDefaults];
                    [self.player first_load];
                    self.player.playNum ++;
                }
            }
            break;
        case MPMovieLoadStateStalled://4
            // 缓冲中
            logdebug(@"%@ Stalled", self.player.originalContentURL);
            self.videoStatusLabel.hidden = NO;
            self.videoStatusLabel.text = @"正在加载...";
            break;
            
        case MPMovieLoadStateUnknown://0
            logdebug(@"未知状态");
        default:
            break;
    }
}

- (void)moviePlayerPlaybackDidFinish:(NSNotification *)notification
{;
    logdebug("PlaybackDidFinishNotification--------------Finish");
    NSNumber *n = [[notification userInfo] objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    switch ([n intValue]) {
        case MPMovieFinishReasonPlaybackEnded:
            logdebug(@"PlaybackEnded");
            self.videoStatusLabel.hidden = YES;
            [self.player stop];
            break;
            
        case MPMovieFinishReasonPlaybackError:
            logdebug(@"PlaybackError");
            self.videoStatusLabel.hidden = NO;
            self.videoStatusLabel.text = @"加载失败";
            break;
            
        case MPMovieFinishReasonUserExited:
            logdebug(@"ReasonUserExited");
            break;
            
        default:
            break;
    }
}

- (void)moviePlayerPlaybackStateDidChange
{
    //logdebug(@"%@ playbackState: %ld", self.player.originalContentURL, (long)self.player.playbackState);
     logdebug(@"layerPlaybackStateDidChangeNotification--------DidChange");
    switch ([self.player playbackState]) {
        case MPMoviePlaybackStateStopped:
            logdebug(@"movie stopped");
            self.videoStatusLabel.hidden = YES;
            [self.playbackButton setImage:[UIImage imageNamed:@"res_lbbVideo/play-playbutton"] forState:UIControlStateNormal];
            break;
            
        case MPMoviePlaybackStatePlaying:
            [self.playbackButton setImage:[UIImage imageNamed:@"res_lbbVideo/player-pausebutton"] forState:UIControlStateNormal];
            logdebug(@"movie playing");
            self.videoStatusLabel.hidden = YES;
            self.player.playaction = @"buffereddrag";
            if (_videoId) {
                if (self.player.playNum >1 && self.player.isReplay == NO) {
                    [self.player replay];
                }
                
            }
            break;
            
        case MPMoviePlaybackStatePaused:
            [self.playbackButton setImage:[UIImage imageNamed:@"res_lbbVideo/play-playbutton"] forState:UIControlStateNormal];
            logdebug(@"movie paused");
            //self.videoStatusLabel.hidden = NO;
            self.player.action++;
            self.player.playaction = @"unbuffereddrag";
            if (_videoId) {
                if (self.player.playableDuration < 5 && self.player.playNum >1 && self.player.sourceURL==nil) {
                    [self.player playlog];
                    
                    if (self.player.action == 1 || self.player.action == 3) {
                        [self.player playlog_php];
                    }
                }
                
            }
            //self.videoStatusLabel.text = @"暂停";
            break;
            
        case MPMoviePlaybackStateInterrupted:
            [self.playbackButton setImage:[UIImage imageNamed:@"res_lbbVideo/play-playbutton"] forState:UIControlStateNormal];
            logdebug(@"movie interrupted");
            self.videoStatusLabel.hidden = NO;
            self.videoStatusLabel.text = @"加载中...";
            break;
            
        case MPMoviePlaybackStateSeekingForward:
            logdebug(@"movie seekingForward");
            self.videoStatusLabel.hidden = YES;
            break;
            
        case MPMoviePlaybackStateSeekingBackward:
            logdebug(@"movie seekingBackward");
            self.videoStatusLabel.hidden = YES;
            break;
            
        default:
            break;
    }
}
# pragma mark - 视频播放状态
- (void)loadVideoStatusLabel
{
    CGRect frame = CGRectZero;
    frame.size.height = 40;
    frame.size.width = 100;
    frame.origin.x = self.overlayView.frame.size.width/2 - frame.size.width/2;
    frame.origin.y = self.overlayView.frame.size.height/2 - frame.size.height/2;
    
    self.videoStatusLabel = [[UILabel alloc] initWithFrame:frame];
    self.videoStatusLabel.text = @"正在加载...";
    self.videoStatusLabel.textColor = [UIColor whiteColor];
    self.videoStatusLabel.backgroundColor = [UIColor clearColor];
    self.videoStatusLabel.font = [UIFont systemFontOfSize:16];
    
    [self.overlayView addSubview:self.videoStatusLabel];
}
-(void)saveNsUserDefaults
{
    //记录退出时播放信息
    NSTimeInterval time = self.player.currentPlaybackTime;
    long long dTime = [[NSNumber numberWithDouble:time] longLongValue];
    NSString *curTime = [NSString stringWithFormat:@"%llu",dTime];
    self.playPosition = [NSDictionary dictionaryWithObjectsAndKeys:
                         curTime,@"playbackTime",
                         nil];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (self.videoId) {
        //在线视频
        [userDefaults setObject:self.playPosition forKey:_videoId];
        
    } else if (self.videoLocalPath) {
        //本地视频
        [userDefaults setObject:self.playPosition forKey:_videoLocalPath];
    }
    //同步到磁盘
    [userDefaults synchronize];
    
    if (time == self.player.duration) {
        //视频结束进度清零
        if (self.videoId) {
            [[NSUserDefaults standardUserDefaults]removeObjectForKey:_videoId];
        }else if (self.videoLocalPath)
        {
            [[NSUserDefaults standardUserDefaults]removeObjectForKey:_videoLocalPath];
            
        }
        [[NSUserDefaults standardUserDefaults]synchronize];
    }
    
}
-(void)readNSUserDefaults
{
    
    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
    if (self.videoId) {
        NSDictionary *playPosition = [userDefaultes dictionaryForKey:_videoId];
        self.player.currentPlaybackTime = [[playPosition valueForKey:@"playbackTime"] floatValue];
        
    }else if (self.videoLocalPath){
        NSDictionary *playPosition = [userDefaultes dictionaryForKey:_videoLocalPath];
        self.player.currentPlaybackTime = [[playPosition valueForKey:@"playbackTime"] floatValue];
    }
}

# pragma mark - timer
- (void)addTimer
{
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(timerHandler) userInfo:nil repeats:YES];
}
- (void)removeTimer
{
    if([self.timer isValid]){
        [self.timer invalidate];
    }
}

- (void)timerHandler
{
    if(!self.videoId){
        self.videoStatusLabel.hidden = YES;
    }
    self.currentPlaybackTimeLabel.text = [DWTools formatSecondsToString:self.player.currentPlaybackTime];
    self.durationLabel.text = [DWTools formatSecondsToString:self.player.duration];
    self.duration_CurrentPlaybackTimeLabel.text = [NSString stringWithFormat:@"%@/%@",self.currentPlaybackTimeLabel.text, self.durationLabel.text];
    self.durationSlider.value = self.player.currentPlaybackTime;
    
    self.historyPlaybackTime = self.player.currentPlaybackTime;
    if(self.isfirst &&self.player.currentPlaybackTime>0){
        self.isfirst = FALSE;
        if (_cbId >= 0) {
            NSDictionary *ret = @{@"btnType":@"100",@"ctime":[NSString stringWithFormat:@"%f",self.player.currentPlaybackTime]};
            [self sendResultEventWithCallbackId:_cbId dataDict:ret errDict:nil doDelete:NO];
        }
    }
    if (!self.hiddenAll) {
        if (self.hiddenDelaySeconds > 0) {
            if (self.hiddenDelaySeconds == 1) {
                [self hiddenAllView];
            }
            self.hiddenDelaySeconds--;
        }
    }
    
    self.movieSubtitleLabel.text = [self.mediaSubtitle searchWithTime:self.player.currentPlaybackTime];
}

- (void)removeAllObserver
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)hiddenAllView
{
    //quanping
    //[[UIApplication sharedApplication] setStatusBarHidden:YES];
    [self hiddenTableViews];
    
    self.backButton.hidden = YES;
    
    self.qualityButton.hidden = YES;
    self.screenSizeButton.hidden = YES;
    
    self.playpreButton.hidden = YES;
    self.playbackButton.hidden = YES;
    self.playnextButton.hidden = YES;
    
    self.playbeilvButton.hidden = YES;
    self.playvolumeButton.hidden = YES;
    self.playbijiButton.hidden = YES;
    self.playtiwenButton.hidden= YES;
    self.playjiangyiButton.hidden =YES;
    
    self.currentPlaybackTimeLabel.hidden = YES;
    self.duration_CurrentPlaybackTimeLabel.hidden = YES;
    self.durationLabel.hidden = YES;
    self.durationSlider.hidden = YES;
    
    self.volumeSlider.hidden = YES;
    self.volumeView.hidden = YES;
    
    self.headerView.hidden = YES;
    self.footerView.hidden = YES;
    
    self.hiddenAll = YES;
    logdebug(@"videoStatusLabel hiddenAllView-----%@",self.videoStatusLabel.hidden?@"YES":@"NO");
}
- (void)hiddenTableViews
{
    self.subtitleView.hidden = YES;
    self.screenSizeView.hidden = YES;
}
- (void)showBasicViews
{
    //quanping
    //[[UIApplication sharedApplication] setStatusBarHidden:NO];
    
    self.backButton.hidden = NO;
    
    self.qualityButton.hidden = NO;
    self.screenSizeButton.hidden = NO;
    
    self.playpreButton.hidden = NO;
    self.playbackButton.hidden = NO;
    self.playnextButton.hidden = NO;
    
    self.playbeilvButton.hidden = NO;
    self.playvolumeButton.hidden = NO;
    self.playbijiButton.hidden = NO;
    self.playtiwenButton.hidden= NO;
    self.playjiangyiButton.hidden =NO;
    
    self.currentPlaybackTimeLabel.hidden = NO;
    self.duration_CurrentPlaybackTimeLabel.hidden=NO;
    self.durationLabel.hidden = NO;
    self.durationSlider.hidden = NO;
    
    self.volumeSlider.hidden = NO;
    self.volumeView.hidden = NO;
    
    self.headerView.hidden = NO;
    self.footerView.hidden = NO;
    self.hiddenAll = NO;
    logdebug(@"videoStatusLabel showBasicViews-----%@",self.videoStatusLabel.hidden?@"YES":@"NO");
}

@end
