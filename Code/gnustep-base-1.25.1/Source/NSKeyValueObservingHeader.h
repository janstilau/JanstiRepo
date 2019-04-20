//
//  KVOHeader.h
//  gdnc
//
//  Created by JustinLau on 2019/4/20.
//

#ifndef KVOHeader_h
#define KVOHeader_h

@interface	GSKVOReplacement : NSObject
{
    Class         original;       /* The original class */
    Class         replacement;    /* The replacement class */
    NSMutableSet  *keys;          /* The observed setter keys */
}

@interface	GSKVOObservation : NSObject
{
@public
    NSObject      *observer;      // Not retained (zeroing weak pointer)
    void          *context;
    int           options;
}
@end

@interface	GSKVOPathInfo : NSObject
{
@public
    unsigned              recursion;
    unsigned              allOptions;
    NSMutableArray        *observations;
    NSMutableDictionary   *change;
}




#endif /* KVOHeader_h */
