//
//  QCHTTPPlugIn.m
//  QCHTTP
//
//  Created by Achim Breidenbach on 21/07/16.
//  Copyright © 2016 Achim Breidenbach. All rights reserved.
//

#import <OpenGL/CGLMacro.h>

#import "QCHTTPPlugIn.h"

#define	kQCPlugIn_Name				@"QCHTTP"
#define	kQCPlugIn_Description		@"QCHTTP description"

static NSString * QCHTTPPlugInInputHTTPLocation = @"inputHTTPLocation";
static NSString * QCHTTPPlugInInputUpdateSignal = @"inputUpdateSignal";

@interface QCHTTPPlugIn () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

+ (NSBundle *)bundle;

@property (strong) NSThread *connectionThread;

// only the connectionThread must access this properties
@property (nonatomic, strong) NSTimer *connectionThreadTimer;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSMutableData *content;
@property (nonatomic, assign) long long contentLength;

@property (copy) NSString *HTTPLocation;
@property (copy) NSDictionary *HTTPHeaders;

@property (strong) NSString *HTTPResponds;
@property (assign) double downloadProgress;
@property (assign) NSNumber *doneSignal;
@property (strong) NSError *error;

@end

@implementation QCHTTPPlugIn

@dynamic inputHTTPLocation;
@dynamic inputHTTPHeaders;
@dynamic inputUpdateSignal;

@dynamic outputHTTPResponds;
@dynamic outputDownloadProgress;
@dynamic outputDoneSignal;

@synthesize connectionThread = _connectionThread;
@synthesize connectionThreadTimer = _connectionThreadTimer;
@synthesize connection = _connection;
@synthesize content = _content;
@synthesize contentLength = _contentLength;

@synthesize HTTPLocation = _HTTPLocation;
@synthesize HTTPHeaders = _HTTPHeaders;

@synthesize HTTPResponds = _HTTPResponds;
@synthesize downloadProgress = _downloadProgress;
@synthesize error = _error;

+ (NSBundle *)bundle
{
	return [NSBundle bundleForClass:self];
}

+ (NSDictionary *)attributes
{
	return @{
			 QCPlugInAttributeNameKey: @"HTTP Request",
  		QCPlugInAttributeDescriptionKey: @"Fetches asynchronously a HTTP request and output the responds.",
			 QCPlugInAttributeCopyrightKey: @"© 2016 Boinx Software Ltd."
			 };
}

+ (NSDictionary *)attributesForPropertyPortWithKey:(NSString *)key
{
	if([key isEqualToString:QCHTTPPlugInInputHTTPLocation])
	{
		return @{ QCPortAttributeNameKey: @"HTTP Location" };
	}
	
	if([key isEqualToString:@"inputHTTPHeaders"])
	{
		return @{ QCPortAttributeNameKey: @"HTTP Headers" };
	}
	
	if([key isEqualToString:QCHTTPPlugInInputUpdateSignal])
	{
		return @{ QCPortAttributeNameKey: @"Update Signal" };
	}
	
	if([key isEqualToString:@"outputHTTPResponds"])
	{
		return @{ QCPortAttributeNameKey: @"HTTP Responds" };
	}
	
	if([key isEqualToString:@"outputDownloadProgress"])
	{
		return @{ QCPortAttributeNameKey: @"Download Progress" };
	}
	
	if([key isEqualToString:@"outputDoneSignal"])
	{
		return @{ QCPortAttributeNameKey: @"Done Signal" };
	}
	
	return nil;
}

+ (NSArray *)plugInKeys
{
	return nil;
}

+ (QCPlugInExecutionMode)executionMode
{
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode)timeMode
{
	return kQCPlugInTimeModeIdle;
}

- (id)init
{
	self = [super init];
	if(self != nil)
	{
		NSThread *connectionThread = [[NSThread alloc] initWithTarget:self selector:@selector(startConnectionThread) object:nil];
		self.connectionThread = connectionThread;
		
		connectionThread.name = @"QCHTTP.ConnectionThead";
		[connectionThread start];
	}
	return self;
}

- (void)dealloc
{
	NSThread *connectionThread = self.connectionThread;
	if(connectionThread != nil)
	{
		[self performSelector:@selector(stopConnectionThread) onThread:connectionThread withObject:nil waitUntilDone:YES];
		self.connectionThread = nil;
	}
	
	[self.connection cancel];
	
	self.connection = nil;
	self.content = nil;
	
	self.HTTPResponds = nil;
	self.doneSignal = nil;
	self.error = nil;
	
	self.HTTPHeaders = nil;
	self.HTTPLocation = nil;
}

- (void)startConnectionThread
{
	@autoreleasepool
	{
		NSTimeInterval timeInterval = [NSDate.distantFuture timeIntervalSinceNow];
		self.connectionThreadTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval target:self selector:@selector(connectionTimerFired) userInfo:nil repeats:NO];
		
		CFRunLoopRun();
	}
}

- (void)stopConnectionThread
{
	[self stopConnection];
	
	if(self.connectionThreadTimer != nil)
	{
		[self.connectionThreadTimer invalidate];
		self.connectionThreadTimer = nil;
	}
	
	CFRunLoopStop(CFRunLoopGetCurrent());
}

- (void)connectionTimerFired
{
	
}

- (void)startConnection
{
	@autoreleasepool
	{
		[self stopConnection];
		
		NSString *HTTPLocation = self.HTTPLocation;
		
		if(HTTPLocation.length == 0)
		{
			return;
		}
		
		NSURL *URL = [NSURL URLWithString:HTTPLocation];
		if(URL.scheme == nil)
		{
			URL = [NSURL fileURLWithPath:HTTPLocation];
		}
		
		// NSLog(@"%@ %@", URL, URL.scheme);
		
		if([URL.scheme isEqualToString:@"file"])
		{
			NSData *data = [NSData dataWithContentsOfURL:URL];
			NSString *fileContent = nil;
			
			if(data != nil)
			{
				fileContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
			}
			
			if(fileContent != nil)
			{
				self.HTTPResponds = fileContent;
				
				self.downloadProgress = 1.0;
				self.doneSignal = @YES;
			}
			else
			{
				self.error = [NSError errorWithDomain:NSOSStatusErrorDomain code:paramErr userInfo:nil];
				
				self.downloadProgress = 0.0;
				self.doneSignal = @NO;
			}
		}
		else
		{
			NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
			
			NSDictionary *HTTPHeaders = self.HTTPHeaders;
			for(NSString *key in HTTPHeaders)
			{
				NSString *value = [HTTPHeaders objectForKey:key];
				[request setValue:value forHTTPHeaderField:key];
			}
			
			self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
			
			self.downloadProgress = 0.0;
			self.doneSignal = @NO;
		}
	}
}

- (void)stopConnection
{
	@autoreleasepool
	{
		[self.connection cancel];
		self.connection = nil;
		
		self.content = nil;
	}
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	if(connection == self.connection)
	{
		[self stopConnection];
		
		self.downloadProgress = 0.0;
		self.doneSignal = @NO;
		
		self.error = error;
	}
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	if(connection == self.connection)
	{
		if(![response isKindOfClass:NSHTTPURLResponse.class])
		{
			[self stopConnection];
			
			self.downloadProgress = 0.0;
			self.doneSignal = @NO;
			
			return;
		}
		
		NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *)response;
		
		NSInteger statusCode = HTTPResponse.statusCode;
		if(statusCode != 200)
		{
			[self stopConnection];
			
			self.downloadProgress = 0.0;
			self.doneSignal = @NO;
			
			NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: [NSHTTPURLResponse localizedStringForStatusCode:statusCode] };
			self.error = [NSError errorWithDomain:NSURLErrorDomain code:statusCode userInfo:userInfo];
			
			return;
		}
		
		NSString *contentLengthString = [HTTPResponse.allHeaderFields objectForKey:@"Content-Length"];
		long long contentLength = [contentLengthString longLongValue];
		self.contentLength = contentLength > 0 ? contentLength : 0;
		
		self.content = [NSMutableData dataWithCapacity:(NSUInteger)contentLength];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	if(connection == self.connection)
	{
		[self.content appendData:data];
		
		if(self.contentLength > 0)
		{
			double downloadProgress = (double)self.content.length / (double)self.contentLength;
			if(downloadProgress > 1.0)
			{
				downloadProgress = 1.0;
			}
			
			self.downloadProgress = downloadProgress;
		}
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if(connection == self.connection)
	{
		NSError *error = nil;
		NSString *httpRespondsString = [[NSString alloc] initWithData:self.content encoding:NSUTF8StringEncoding];	// TODO get encoding from reposndes!!!

		if(httpRespondsString != nil)
		{
			self.HTTPResponds = httpRespondsString;
			
			self.downloadProgress = 1.0;
			self.doneSignal = @YES;
		}
		else
		{
			self.downloadProgress = 0.0;
			self.doneSignal = @NO;
			
			self.error = error;
		}
		
		[self stopConnection];
	}
}

@end


@implementation QCHTTPPlugIn (Execution)

- (BOOL)startExecution:(id<QCPlugInContext>)context
{
	return YES;
}

- (void)enableExecution:(id <QCPlugInContext>)context
{
}

- (BOOL)execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary *)arguments
{
	if([self didValueForInputKeyChange:QCHTTPPlugInInputUpdateSignal] && self.inputUpdateSignal == YES)
	{
		self.HTTPLocation = self.inputHTTPLocation;
		self.HTTPHeaders = self.HTTPHeaders;
		
		[self performSelector:@selector(startConnection) onThread:self.connectionThread withObject:nil waitUntilDone:NO];
	}
	
	if(self.doneSignal != nil)
	{
		if(self.doneSignal.boolValue)
		{
			self.outputHTTPResponds = self.HTTPResponds;
			self.outputDoneSignal = YES;
			
			self.HTTPResponds = nil;
			
			self.doneSignal = @NO;
		}
		else
		{
			self.outputDoneSignal = NO;
			
			self.doneSignal = nil;
		}
	}
	
	if(self.downloadProgress >= 0.0)
	{
		self.outputDownloadProgress = self.downloadProgress;
		
		self.downloadProgress = -1.0;
	}
	
	if(self.error)
	{
		[context logMessage:@"JSON Import error: %@", self.error];
		
		self.error = nil;
	}
	
	return YES;
}

- (void)disableExecution:(id <QCPlugInContext>)context
{
}

- (void)stopExecution:(id <QCPlugInContext>)context
{
}

@end
