
//
//  NetWorkSpeed.m
//  PCLadyVideoPlayer
//
//  Created by luo.h on 16/6/22.
//  Copyright © 2016年 PCLady. All rights reserved.
//

#import "NetWorkMonitorView.h"

#include <arpa/inet.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <net/if_dl.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define KSCREEN_WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define KSCREEN_HEIGHT ([[UIScreen mainScreen] bounds].size.height)

#define RGBColor(r, g, b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1]
#define RGBAColor(r, g, b ,a) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:a]
#define RandColor RGBColor(arc4random_uniform(255), arc4random_uniform(255), arc4random_uniform(255))

@interface NetWorkMonitorView ()

@property(nonatomic,strong) UILabel *label;
@property(nonatomic,strong) UIButton *swithBtn;
@property(nonatomic,strong) UIButton *closeBtn;
@property(nonatomic,strong) NSTimer *netTimer;

@end

@implementation NetWorkMonitorView

typedef struct NetSpeedBytes {
    long long int inBytes;
    long long int outBytes;
}NetSpeedBytes;

static NSString *const WWANSentKey = @"WWANSent";
static NSString *const WWANReceivedKey = @"WWANReceived";
static NSString *const WiFiSentKey = @"WiFiSent";
static NSString *const WiFiReceivedKey = @"WiFiReceived";



- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code[]
        [self addSubview:self.label];
        [self addSubview:self.swithBtn];
        [self addSubview:self.closeBtn];
        
        self.tag=[@"NetWorkMonitorView" hash];
        self.backgroundColor=[[UIColor blackColor] colorWithAlphaComponent:0.3];
    }
    return self;
}


+(instancetype)speedView
{
    return [[NetWorkMonitorView alloc] initWithFrame:CGRectMake(0,60,120,50)];
}


- (void)dealloc
{
    [_netTimer invalidate];
    _netTimer=nil;
}

//names of interfaces: en0 is WiFi ,pdp_ip0 is WWAN
// from
//http://stackoverflow.com/questions/7946699/iphone-data-usage-tracking-monitoring?lq=1

//Search by prefix because there could be serveral internal interfaces i.e pdp_ip1.
NSString *const kInterfacePrefixWifi = @"en";
NSString *const kInterfacePrefixWWan = @"pdp_ip";


//每秒网速

static inline NetSpeedBytes getBytes() {
    static NSTimeInterval lastTime = 0;
    static NetSpeedBytes  lastNetworkBytes = {0,0};
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval duration = currentTime - lastTime;
    
    NetSpeedBytes currentNetworkBytes = {0,0};
    NSDictionary *speedDict= bytesDataCounters();
    if ([speedDict[WiFiReceivedKey] unsignedLongLongValue]>0) {
        currentNetworkBytes.inBytes=[speedDict[WiFiReceivedKey] unsignedLongLongValue];
        currentNetworkBytes.outBytes=[speedDict[WiFiSentKey] unsignedLongLongValue];
    }else{
        currentNetworkBytes.inBytes=[speedDict[WWANSentKey] unsignedLongLongValue];
        currentNetworkBytes.outBytes=[speedDict[WWANReceivedKey] unsignedLongLongValue];
    }
    NetSpeedBytes netbytes = {0,0};
    if (lastTime==0||duration==0) {
        
    } else {
        netbytes.outBytes = (currentNetworkBytes.outBytes - lastNetworkBytes.outBytes)/duration;
        netbytes.inBytes = (currentNetworkBytes.inBytes - lastNetworkBytes.inBytes)/duration;
    }
    lastTime = currentTime;
    lastNetworkBytes = currentNetworkBytes;
    return netbytes;
};


/**
 *  全局数据流量
 */
static inline NSDictionary *bytesDataCounters() {
    struct ifaddrs *addrs;
    const struct ifaddrs *cursor;
    
    u_int32_t WiFiSent = 0;
    u_int32_t WiFiReceived = 0;
    u_int32_t WWANSent = 0;
    u_int32_t WWANReceived = 0;
    
    if (getifaddrs(&addrs) == 0)
    {
        cursor = addrs;
        while (cursor != NULL)
        {
            if (cursor->ifa_addr->sa_family == AF_LINK)
            {
#ifdef DEBUG
                const struct if_data *ifa_data = (struct if_data *)cursor->ifa_data;
                if(ifa_data != NULL)
                {
//                    NSLog(@"Interface name %s: sent %tu received %tu",cursor->ifa_name,ifa_data->ifi_obytes,ifa_data->ifi_ibytes);
                }
#endif
                
                // name of interfaces:
                // en0 is WiFi
                // pdp_ip0 is WWAN
                NSString *name = [NSString stringWithFormat:@"%s",cursor->ifa_name];
                if ([name hasPrefix:@"en"])
                {
                    const struct if_data *ifa_data = (struct if_data *)cursor->ifa_data;
                    if(ifa_data != NULL)
                    {
                        WiFiSent += ifa_data->ifi_obytes;
                        WiFiReceived += ifa_data->ifi_ibytes;
                    }
                }
                
                if ([name hasPrefix:@"pdp_ip"])
                {
                    const struct if_data *ifa_data = (struct if_data *)cursor->ifa_data;
                    if(ifa_data != NULL)
                    {
                        WWANSent += ifa_data->ifi_obytes;
                        WWANReceived += ifa_data->ifi_ibytes;
                    }
                }
            }
            
            cursor = cursor->ifa_next;
        }
        
        freeifaddrs(addrs);
    }
    
    return @{WiFiSentKey:[NSNumber numberWithUnsignedInt:WiFiSent],
             WiFiReceivedKey:[NSNumber numberWithUnsignedInt:WiFiReceived],
             WWANSentKey:[NSNumber numberWithUnsignedInt:WWANSent],
             WWANReceivedKey:[NSNumber numberWithUnsignedInt:WWANReceived]};
}



/**
 *  字节转换
 */
static inline NSString *bytesToSpeedStr(long long int bytes)
{
    if(bytes < 1024) // B
    {
        return [NSString stringWithFormat:@"%lldB/s", bytes];
    }
    else if(bytes >= 1024 && bytes < 1024 * 1024) // KB
    {
        return [NSString stringWithFormat:@"%.1fKB/s", (double)bytes / 1024];
    }
    else if(bytes >= 1024 * 1024 && bytes < 1024 * 1024 * 1024) // MB
    {
        return [NSString stringWithFormat:@"%.2fMB", (double)bytes / (1024 * 1024)];
    }
    else    // GB
    {
        return [NSString stringWithFormat:@"%.3fGB", (double)bytes / (1024 * 1024 * 1024)];
    }
}



-(void)startMonitor
{
    NSLog(@"开始监控");
   self.netTimer= [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(showNetSpeed) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.netTimer forMode:NSRunLoopCommonModes];
}

-(void)stopMonitor
{
    NSLog(@"停止监控");
    self.label.text=@"上传:0 B/s\n下载:0 B/s";
    [_netTimer invalidate];
    _netTimer=nil;
}

CGPoint originalLocation;   //全局变量 用于存储起始位置
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches   anyObject];
    originalLocation = [touch locationInView:self];
    
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:self];
    CGRect frame = self.frame;
    frame.origin.x += currentLocation.x - originalLocation.x;
    frame.origin.y += currentLocation.y - originalLocation.y;
    NSLog(@"frame=%@",NSStringFromCGRect(frame));
    self.frame = frame;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event
{
    CGRect  theRect=self.frame;
    CGFloat viewX,viewY;
  
    if (self.frame.origin.x<0) {
        viewX=0;//X最小值 0;
    }else if (CGRectGetMaxX(self.frame)>KSCREEN_WIDTH){
        viewX=KSCREEN_WIDTH-theRect.size.width;//X最大值KSCREEN_WIDTH
    }else{
        viewX=theRect.origin.x;
    }
    
    if (self.frame.origin.y<0) {
        viewY=0;
    }else if (CGRectGetMaxY(self.frame)>KSCREEN_HEIGHT){
        viewY= KSCREEN_HEIGHT-self.frame.size.height;
    }else{
        viewY=theRect.origin.y;
    }
    
    [UIView animateWithDuration:0.38 animations:^{
        self.frame=CGRectMake(viewX, viewY, theRect.size.width, theRect.size.height);
    }];
    
    NSLog(@"theRect:%@",NSStringFromCGRect(theRect));
}



//显示网速
-(void)showNetSpeed
{
    NetSpeedBytes netDict=getBytes();
    NSString *downSpeed = bytesToSpeedStr(netDict.inBytes);
    NSString *uploadSpeed = bytesToSpeedStr(netDict.outBytes);
    self.label.text=[NSString stringWithFormat:@"上传:%@\n下载:%@",uploadSpeed,downSpeed];
}

- (UILabel *)label {
	if(_label == nil) {
        _label = [[UILabel alloc] initWithFrame:CGRectMake(0,0,100, self.bounds.size.height)];
        _label.textAlignment = NSTextAlignmentLeft;
        _label.backgroundColor = [UIColor clearColor];
        _label.textColor = [UIColor redColor];
        _label.numberOfLines=2;
        _label.font = [UIFont systemFontOfSize:14];
        self.label.text=@"上传:0 B/s\n下载:0 B/s";
    }
	return _label;
}



- (UIButton *)swithBtn {
    if(_swithBtn == nil) {
        _swithBtn = [UIButton  buttonWithType:UIButtonTypeCustom];
        [_swithBtn setTitle:@"开启" forState:UIControlStateNormal];
        [_swithBtn setTitle:@"停止" forState:UIControlStateSelected];
        _swithBtn.titleLabel.font=[UIFont systemFontOfSize:12];
        [_swithBtn addTarget:self action:@selector(swithButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        _swithBtn.frame=CGRectMake(self.bounds.size.width-50, 0,50, self.bounds.size.height);
    }
    return _swithBtn;
}


- (UIButton *)closeBtn {
    if(_closeBtn == nil) {
        _closeBtn = [UIButton  buttonWithType:UIButtonTypeCustom];
        [_closeBtn setTitle:@"X" forState:UIControlStateNormal];
        _closeBtn.titleLabel.font=[UIFont systemFontOfSize:12];
        _closeBtn.backgroundColor=[[UIColor blackColor] colorWithAlphaComponent:0.3];
        [_closeBtn addTarget:self action:@selector(closeButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        _closeBtn.frame=CGRectMake(self.bounds.size.width-14, -8,22, 22);
        _closeBtn.layer.cornerRadius=11;
    }
    return _closeBtn;
}

-(void)closeButtonClick:(UIButton *)sender
{
    [self startMonitor];
    [self removeFromSuperview];
}



-(void)swithButtonClick:(UIButton *)sender
{
    sender.selected=!sender.selected;
    if (sender.selected) {
        [self startMonitor];
    }else{
        [self stopMonitor];
    }
    
}

+ (instancetype)HUDForView:(UIView *)view {
    NSEnumerator *subviewsEnum = [view.subviews reverseObjectEnumerator];
    for (UIView *subview in subviewsEnum) {
        if ([subview isKindOfClass:self]) {
            return (NetWorkMonitorView *)subview;
        }
    }
    return nil;
}

@end


@implementation UIViewController (Swizzle)


#if defined(DEBUG) && DEBUG
+ (void)load{
    //方法交换应该被保证，在程序中只会执行一次
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        //方法交换
        NetSwizzlingMethods([self class], @selector(viewWillAppear:), @selector(netSwiz_viewWillAppear:));
    });
}
#endif


/** 方法交换*/

static inline void NetSwizzlingMethods(Class cls, SEL systemSel, SEL newSel)
{
    //两个方法的Method
    Method systemMethod = class_getInstanceMethod(cls, systemSel);
    Method newMethod = class_getInstanceMethod(cls, newSel);
    
    //首先动态添加方法，实现是被交换的方法，返回值表示添加成功还是失败
    BOOL isAddMethod = class_addMethod(cls,systemSel,
                                       method_getImplementation(newMethod),
                                       method_getTypeEncoding(newMethod));
    if(isAddMethod){
        //如果成功，说明类中不存在这个方法的实现
        //将被交换方法的实现替换到这个并不存在的实现
        class_replaceMethod(cls, newSel, method_getImplementation(systemMethod), method_getTypeEncoding(systemMethod));
    }else{
        //否则，交换两个方法的实现(改变两个方法的具体指针指向)
        method_exchangeImplementations(systemMethod, newMethod);
    }
}



- (void)netSwiz_viewWillAppear:(BOOL)animated{
    //看起来像是死循环，但是其实自己的实现已经被替换了
    [self netSwiz_viewWillAppear:animated];
    NSLog(@"✅VC->%@",[self class]);
    NSString *classStr=NSStringFromClass([self class]);
    [self handleClass:classStr];
}




-(void)handleClass:(NSString *)classStr
{
    UIWindow *window = [[UIApplication sharedApplication].windows lastObject];
    NSLog(@"window:%@",window);
    
    if (![NSStringFromClass(window.class) isEqualToString:@"UIWindow"]) {
        return;//ignor UITextEffectsWindow...
    }
    NetWorkMonitorView *view=[window viewWithTag:[@"NetWorkMonitorView" hash]];
    if (!view&&window) {
        view=[NetWorkMonitorView speedView];
        [window addSubview:view];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [window bringSubviewToFront:view];
        });
    }
    
    
#pragma mark--也可以在控制指定ViewController的显示隐藏
//    if ([classStr isEqualToString:@"ViewController1"]||[classStr isEqualToString:@"ViewController2"]){
//        //显示
//        
//    }else{
//        //隐藏
//        NetWorkSpeedView *view=[NetWorkSpeedView HUDForView:window];
//        if (view) {
//            [view stopMonitor];
//            view.hidden=YES;
//        }
//        NSLog(@"✅VC->%@",[self class]);
//    }
}


@end
