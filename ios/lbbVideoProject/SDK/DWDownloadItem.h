#import <Foundation/Foundation.h>
#import "DWDownloader.h"
enum {
    DWDownloadStatusWait = 1,
    DWDownloadStatusStart,
    DWDownloadStatusDownloading,
    DWDownloadStatusPause,
    DWDownloadStatusFinish,
    DWDownloadStatusFail
};

typedef NSInteger DWDownloadStatus;
@interface DWDownloadItem : NSObject
@property (strong, nonatomic)NSString *videoId;
@property (strong, nonatomic)DWDownloader *downloader;
@property (assign, nonatomic)DWDownloadStatus videoDownloadStatus;
@property (assign, nonatomic)NSTimeInterval time;
@property (assign, nonatomic)int count;


- (id)initWithVideoId:(NSString *)videoId;
- (NSDictionary *)getItemDictionary;
@end
