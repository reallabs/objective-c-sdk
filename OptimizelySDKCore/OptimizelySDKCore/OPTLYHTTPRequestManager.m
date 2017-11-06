/****************************************************************************
 * Copyright 2016-2017, Optimizely, Inc. and contributors                   *
 *                                                                          *
 * Licensed under the Apache License, Version 2.0 (the "License");          *
 * you may not use this file except in compliance with the License.         *
 * You may obtain a copy of the License at                                  *
 *                                                                          *
 *    http://www.apache.org/licenses/LICENSE-2.0                            *
 *                                                                          *
 * Unless required by applicable law or agreed to in writing, software      *
 * distributed under the License is distributed on an "AS IS" BASIS,        *
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
 * See the License for the specific language governing permissions and      *
 * limitations under the License.                                           *
 ***************************************************************************/

#import "OPTLYErrorHandlerMessages.h"
#import "OPTLYHTTPRequestManager.h"
#import "OPTLYLog.h"
#import "OPTLYLoggerMessages.h"

static NSString * const kHTTPRequestMethodGet = @"GET";
static NSString * const kHTTPRequestMethodPost = @"POST";
static NSString * const kHTTPHeaderFieldContentType = @"Content-Type";
static NSString * const kHTTPHeaderFieldValueApplicationJSON = @"application/json";

// TODO: Wrap this in a TEST preprocessor definition
@interface OPTLYHTTPRequestManager()
@property (nonatomic, assign) NSInteger retryAttemptTest;
@property (nonatomic, strong) NSMutableArray *delaysTest;
@end

@implementation OPTLYHTTPRequestManager

# pragma mark - Object Initializers

- (id)init
{
    NSAssert(YES, @"Use initWithURL initialization method.");
    
    self = [super init];
    return self;
}

// Create global serial GCD queue for NSURL tasks
dispatch_queue_t networkTasksQueue()
{
    static dispatch_queue_t _networkTasksQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _networkTasksQueue = dispatch_queue_create("com.Optimizely.networkTasksQueue", DISPATCH_QUEUE_CONCURRENT);
    });
    return _networkTasksQueue;
}

# pragma mark - GET
- (void)GETWithURL:(NSURL *)url
        completion:(OPTLYHTTPRequestManagerResponse)completion {
    [self GETWithParameters:nil url:url completionHandler:completion];
}

- (void)GETWithBackoffRetryInterval:(NSInteger)backoffRetryInterval
                                url:(NSURL *)url
                            retries:(NSInteger)retries
                  completionHandler:(OPTLYHTTPRequestManagerResponse)completion
{
    // TODO: Wrap this in a TEST preprocessor definition
    self.delaysTest = [NSMutableArray new];
    
    [self GETWithParameters:nil
                        url:url
       backoffRetryInterval:backoffRetryInterval
                    retries:retries
          completionHandler:completion];
}

# pragma mark - GET (with parameters)
- (void)GETWithParameters:(NSDictionary *)parameters
                      url:(NSURL *)url
        completionHandler:(OPTLYHTTPRequestManagerResponse)completion
{
    NSURLSession *ephemeralSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURL *urlWithParameterQuery = [self buildQueryURL:url withParameters:parameters];
    NSURLSessionDataTask *downloadTask = [ephemeralSession dataTaskWithURL:urlWithParameterQuery
                                                         completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                             if (completion) {
                                                                 completion(data, response, error);
                                                             }
                                                         }];
    
    [downloadTask resume];
}

- (void)GETWithParameters:(NSDictionary *)parameters
                      url:(NSURL *)url
     backoffRetryInterval:(NSInteger)backoffRetryInterval
                  retries:(NSInteger)retries
        completionHandler:(OPTLYHTTPRequestManagerResponse)completion
{
    // TODO: Wrap this in a TEST preprocessor definition
    self.delaysTest = [NSMutableArray new];
    
    [self GETWithParameters:parameters
                        url:url
       backoffRetryInterval:backoffRetryInterval
                    retries:retries
          completionHandler:completion
        backoffRetryAttempt:0
                      error:nil];
}

- (void)GETWithParameters:(NSDictionary *)parameters
                      url:(NSURL *)url
     backoffRetryInterval:(NSInteger)backoffRetryInterval
                  retries:(NSInteger)retries
        completionHandler:(OPTLYHTTPRequestManagerResponse)completion
      backoffRetryAttempt:(NSInteger)backoffRetryAttempt
                    error:(NSError *)error
{
    
    OPTLYLogDebug(OPTLYHTTPRequestManagerGETWithParametersAttempt, backoffRetryAttempt);
    
    // TODO: Wrap this in a TEST preprocessor definition
    self.retryAttemptTest = backoffRetryAttempt;
    
    if (backoffRetryAttempt > retries) {
        if (completion) {
            NSString *errorMessage = [NSString stringWithFormat:OPTLYErrorHandlerMessagesHTTPRequestManagerGETRetryFailure, error];
            NSError *error = [NSError errorWithDomain:OPTLYErrorHandlerMessagesDomain
                                                 code:OPTLYErrorTypesHTTPRequestManager
                                             userInfo:@{ NSLocalizedDescriptionKey : errorMessage }];
            OPTLYLogDebug(errorMessage);
            completion(nil, nil, error);
        }
        
        // TODO: Wrap this in a TEST preprocessor definition
        self.delaysTest = nil;
        
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [self GETWithParameters:parameters
                        url:url
          completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
              if (error) {
                  dispatch_time_t delayTime = [weakSelf backoffDelay:backoffRetryAttempt
                                                backoffRetryInterval:backoffRetryInterval];
                  dispatch_after(delayTime, networkTasksQueue(), ^(void){
                      
                      [weakSelf GETWithParameters:parameters
                                              url:url
                             backoffRetryInterval:backoffRetryInterval
                                          retries:retries
                                completionHandler:completion
                              backoffRetryAttempt:backoffRetryAttempt+1
                                            error:error];
                  });
              } else {
                  if (completion) {
                      completion(data, response, error);
                  }
              }
          }];
}

# pragma mark - GET (if modified)
- (void)GETIfModifiedSince:(NSString *)lastModifiedDate
                       url:(NSURL *)url
         completionHandler:(OPTLYHTTPRequestManagerResponse)completion
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setValue:lastModifiedDate forHTTPHeaderField:@"If-Modified-Since"];
    
    NSURLSession *ephemeralSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSURLSessionDataTask *dataTask = [ephemeralSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (completion) {
            completion(data, response, error);
        }
    }];
    
    [dataTask resume];
}

- (void)GETIfModifiedSince:(NSString *)lastModifiedDate
                       url:(NSURL *)url
      backoffRetryInterval:(NSInteger)backoffRetryInterval
                   retries:(NSInteger)retries
         completionHandler:(OPTLYHTTPRequestManagerResponse)completion
{
    // TODO: Wrap this in a TEST preprocessor definition
    self.delaysTest = [NSMutableArray new];
    
    [self GETIfModifiedSince:lastModifiedDate
                         url:url
        backoffRetryInterval:backoffRetryInterval
                     retries:retries
           completionHandler:completion
         backoffRetryAttempt:0
                       error:nil];
}

- (void)GETIfModifiedSince:(NSString *)lastModifiedDate
                       url:(NSURL *)url
      backoffRetryInterval:(NSInteger)backoffRetryInterval
                   retries:(NSInteger)retries
         completionHandler:(OPTLYHTTPRequestManagerResponse)completion
       backoffRetryAttempt:(NSInteger)backoffRetryAttempt
                     error:(NSError *)error
{
    OPTLYLogDebug(OPTLYHTTPRequestManagerGETIfModifiedSince, backoffRetryAttempt);
    
    // TODO: Wrap this in a TEST preprocessor definition
    self.retryAttemptTest = backoffRetryAttempt;
    
    if (backoffRetryAttempt > retries) {
        if (completion) {
            NSString *errorMessage = [NSString stringWithFormat:OPTLYErrorHandlerMessagesHTTPRequestManagerGETIfModifiedFailure, error];
            NSError *error = [NSError errorWithDomain:OPTLYErrorHandlerMessagesDomain
                                                 code:OPTLYErrorTypesHTTPRequestManager
                                             userInfo:@{ NSLocalizedDescriptionKey : errorMessage }];
            OPTLYLogDebug(errorMessage);
            completion(nil, nil, error);
        }
        
        // TODO: Wrap this in a TEST preprocessor definition
        self.delaysTest = nil;
        
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [self GETIfModifiedSince:lastModifiedDate
                         url:url
           completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
               NSInteger statusCode = 503;
               if (response != nil && error == nil) {
                   NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                   statusCode = (long)[httpResponse statusCode];
               }
               if (error != nil || statusCode >= 400) {
                   dispatch_time_t delayTime = [weakSelf backoffDelay:backoffRetryAttempt
                                                 backoffRetryInterval:backoffRetryInterval];
                   dispatch_after(delayTime, networkTasksQueue(), ^(void){
                       [weakSelf GETIfModifiedSince:lastModifiedDate
                                                url:url
                               backoffRetryInterval:backoffRetryInterval
                                            retries:retries
                                  completionHandler:completion
                                backoffRetryAttempt:backoffRetryAttempt+1
                                              error:error];
                   });
               } else {
                   if (completion) {
                       completion(data, response, error);
                   }
               }
           }];
}


# pragma mark - POST
- (void)POSTWithParameters:(NSDictionary *)parameters
                       url:(NSURL *)url
         completionHandler:(OPTLYHTTPRequestManagerResponse)completion
{
    NSURLSession *ephemeralSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:kHTTPRequestMethodPost];
    
    NSError *JSONSerializationError = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:parameters
                                                   options:kNilOptions error:&JSONSerializationError];
    if (JSONSerializationError) {
        if (completion) {
            completion(nil, nil, JSONSerializationError);
        }
        return;
    }
    
    [request addValue:kHTTPHeaderFieldValueApplicationJSON forHTTPHeaderField:kHTTPHeaderFieldContentType];
    
    NSURLSessionUploadTask *uploadTask = [ephemeralSession uploadTaskWithRequest:request
                                                                        fromData:data
                                                               completionHandler:^(NSData *data,NSURLResponse *response,NSError *error) {
                                                                   if (completion) {
                                                                       completion(data, response, error);
                                                                   }
                                                               }];
    
    [uploadTask resume];
}

- (void)POSTWithParameters:(nonnull NSDictionary *)parameters
                       url:(NSURL *)url
      backoffRetryInterval:(NSInteger)backoffRetryInterval
                   retries:(NSInteger)retries
         completionHandler:(nullable OPTLYHTTPRequestManagerResponse)completion
{
    // TODO: Wrap this in a TEST preprocessor definition
    self.delaysTest = [NSMutableArray new];
    
    [self POSTWithParameters:parameters
                         url:url
        backoffRetryInterval:backoffRetryInterval
                     retries:retries
           completionHandler:completion
         backoffRetryAttempt:0
                       error:nil];
}

- (void)POSTWithParameters:(NSDictionary *)parameters
                       url:(NSURL *)url
      backoffRetryInterval:(NSInteger)backoffRetryInterval
                   retries:(NSInteger)retries
         completionHandler:(OPTLYHTTPRequestManagerResponse)completion
       backoffRetryAttempt:(NSInteger)backoffRetryAttempt
                     error:(NSError *)error
{
    OPTLYLogDebug(OPTLYHTTPRequestManagerPOSTWithParameters, backoffRetryAttempt);
    
    // TODO: Wrap this in a TEST preprocessor definition
    self.retryAttemptTest = backoffRetryAttempt;
    
    if (backoffRetryAttempt > retries) {
        if (completion) {
            NSString *errorMessage = [NSString stringWithFormat:OPTLYErrorHandlerMessagesHTTPRequestManagerPOSTRetryFailure, error];
            NSError *error = [NSError errorWithDomain:OPTLYErrorHandlerMessagesDomain
                                                 code:OPTLYErrorTypesHTTPRequestManager
                                             userInfo:@{ NSLocalizedDescriptionKey : errorMessage }];
            OPTLYLogDebug(errorMessage);
            completion(nil, nil, error);
        }
        
        // TODO: Wrap this in a TEST preprocessor definition
        self.delaysTest = nil;
        
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [self POSTWithParameters:parameters
                         url:url
           completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
               if (error) {
                   dispatch_time_t delayTime = [weakSelf backoffDelay:backoffRetryAttempt
                                                 backoffRetryInterval:backoffRetryInterval];
                   dispatch_after(delayTime, networkTasksQueue(), ^(void){
                       [weakSelf POSTWithParameters:parameters
                                                url:url
                               backoffRetryInterval:backoffRetryInterval
                                            retries:retries
                                  completionHandler:completion
                                backoffRetryAttempt:backoffRetryAttempt+1
                                              error:error];
                   });
               } else {
                   if (completion) {
                       completion(data, response, error);
                   }
               }
           }];
}

# pragma mark - Helper Methods

// calculates the exponential backoff time based on the retry attempt number
- (dispatch_time_t)backoffDelay:(NSInteger)backoffRetryAttempt
           backoffRetryInterval:(NSInteger)backoffRetryInterval
{
    uint32_t exponentialMultiplier = pow(2.0, backoffRetryAttempt);
    uint64_t delay_ns = backoffRetryInterval * exponentialMultiplier * NSEC_PER_MSEC;
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, delay_ns);
    
    OPTLYLogDebug(OPTLYHTTPRequestManagerBackoffRetryStates, backoffRetryAttempt, exponentialMultiplier, delay_ns, delayTime);
    
    // TODO: Wrap this in a TEST preprocessor definition
    //JJ: Adding this so the damn thing does not crash as much
    if(self.delaysTest count] > backoffRetryAttempt) {
      self.delaysTest[backoffRetryAttempt] = [NSNumber numberWithLongLong:delay_ns];  
    }    
    
    return delayTime;
}

- (NSURL *)buildQueryURL:(NSURL *)url
          withParameters:(NSDictionary *)parameters
{
    if (parameters == nil || [parameters count] == 0) {
        return url;
    }
    
    NSURLComponents *components = [[NSURLComponents alloc] init];
    
    components.scheme = url.scheme;
    components.host = url.host;
    components.path = url.path;
    
    NSMutableArray *queryItems = [NSMutableArray new];
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop)
     {
         NSURLQueryItem *queryItem = [NSURLQueryItem queryItemWithName:key value:object];
         [queryItems addObject:queryItem];
     }];
    components.queryItems = queryItems;
    
    return components.URL;
}

@end
