//
//  ViewController.m
//  NetWorkMonitorView
//
//  Created by luo.h on 16/7/1.
//  Copyright © 2016年 PCLady. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=[UIColor clearColor];
    
    // Do any additional setup after loading the view, typically from a nib.
    CGRect bouds = [[UIScreen mainScreen] bounds];
    UIWebView* webView = [[UIWebView alloc]initWithFrame:bouds];
    webView.scalesPageToFit = YES;//自动对页面进行缩放以适应屏幕
    NSURL* url = [NSURL URLWithString:@"http://www.baidu.com"];
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    [webView loadRequest:request];//加载
    [self.view addSubview:webView];
}


@end
