//
//  QCHTTPPlugIn.h
//  QCHTTP
//
//  Created by Achim Breidenbach on 21/07/16.
//  Copyright © 2016 Achim Breidenbach. All rights reserved.
//

#import <Quartz/Quartz.h>

@interface QCHTTPPlugIn : QCPlugIn

{
	NSThread *_connectionThread;
	NSTimer *_connectionThreadTimer;
	NSURLConnection *_connection;
	NSMutableData *_content;
	long long _contentLength;
	
	NSString *_HTTPLocation;
	NSDictionary *_HTTPHeaders;
	
	NSString *_HTTPResponds;
	double _downloadProgress;
	NSError *_error;
}

@property (assign) NSString *inputHTTPLocation;
@property (assign) NSDictionary *inputHTTPHeaders;
@property (assign) BOOL inputUpdateSignal;

@property (assign) NSString *outputHTTPResponds;
@property (assign) double outputDownloadProgress;
@property (assign) BOOL outputDoneSignal;

@end
