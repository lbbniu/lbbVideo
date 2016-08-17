#import "DWDownloadItem.h"
@implementation DWDownloadItem

- (id)initWithVideoId:(NSString *)videoId
{
    self = [super init];
    if (self) {
        _videoId = videoId;
    }
    return self;
}

- (NSDictionary *)getItemDictionary
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    if (self.videoId) {
        [dict setObject:self.videoId forKey:@"videoId"];
    }
    return dict;
}
@end