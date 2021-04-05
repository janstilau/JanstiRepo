#import <Foundation/Foundation.h>

@class BHContext;

/*
 这个类, 记录的是 service, 也就是 protocol, 和对应的 imp 类之间的管理.
 */

@interface BHServiceManager : NSObject

@property (nonatomic, assign) BOOL  enableException;

+ (instancetype)sharedManager;

- (void)registerLocalServices;

- (void)registerService:(Protocol *)service implClass:(Class)implClass;

- (id)createService:(Protocol *)service;
- (id)createService:(Protocol *)service withServiceName:(NSString *)serviceName;
- (id)createService:(Protocol *)service withServiceName:(NSString *)serviceName shouldCache:(BOOL)shouldCache;

- (id)getServiceInstanceFromServiceName:(NSString *)serviceName;
- (void)removeServiceWithServiceName:(NSString *)serviceName;

@end
