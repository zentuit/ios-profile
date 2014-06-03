//
//  AuthController.m
//  SoomlaiOSProfile
//
//  Created by Gur Dotan on 6/3/14.
//  Copyright (c) 2014 Soomla. All rights reserved.
//

#import "AuthController.h"
#import "UserProfile.h"
#import "UserProfileStorage.h"
#import "UserProfileNotFoundException.h"
#import "UserProfileEventHandling.h"
#import "IAuthProvider.h"
#import "Reward.h"
#import "StoreUtils.h"

@implementation AuthController

static NSString* TAG = @"SOOMLA AuthController";

- (id)init {
    if (self = [super init]) {

        // TODO: Check if providerPkgPrefix can be omitted completely in iOS
        if (![self loadProvidersWithManifestKey:@"auth.provider" andProviderPkgPrefix:@"com.soomla.profile.auth."]) {
            NSString* msg = @"You don't have a IAuthProvider service attached. \
                            Decide which IAuthProvider you want, add it to SoomlaiOSProfile-Info.plist \
                            and add its static libraries and headers to the target's search path.";
            LogDebug(TAG, msg);
        }
    }

    return self;
}

- (void)loginWithProvider:(enum Provider)provider andReward:(Reward *)reward {
    
    
    id<IAuthProvider> authProvider = (id<IAuthProvider>)[self getProvider:provider];
    [UserProfileEventHandling postLoginStarted:provider];
    
    // Perform login process
    [authProvider login:^(enum Provider provider) {
        [authProvider getUserProfile: ^(UserProfile *userProfile) {
            [UserProfileStorage setUserProfile:userProfile];
            [UserProfileEventHandling postLoginFinished:userProfile];
            
            if (reward) {
                [reward give];
            }
        } fail:^(NSString *message) {
            [UserProfileEventHandling postLoginFailed:message];
        }];
    } fail:^(NSString *message) {
        [UserProfileEventHandling postLoginFailed:message];
    } cancel:^{
        [UserProfileEventHandling postLoginCancelled];
    }];
}

- (void)logoutWithProvider:(enum Provider)provider {
    
    id<IAuthProvider> authProvider = (id<IAuthProvider>)[self getProvider:provider];
    UserProfile* userProfile = nil;
    
    @try {
        userProfile = [self getUserProfileLocallyWithProvider:provider];
    }
    @catch (NSException *ex) {
        NSLog(@"%@",[ex callStackSymbols]);
    }
    
    // Perform logout process
    [UserProfileEventHandling postLogoutStarted:provider];
    [authProvider logout:^() {
        if (userProfile) {
            [UserProfileStorage removeUserProfile:userProfile];
            [UserProfileEventHandling postLogoutFinished:userProfile];
        }
    }
    fail:^(NSString* message) {
        [UserProfileEventHandling postLogoutFailed:message];
    }];
}

- (UserProfile *)getUserProfileLocallyWithProvider:(enum Provider)provider {
    UserProfile* userProfile = [UserProfileStorage getUserProfile:provider];
    if (!userProfile) {
        @throw [[UserProfileNotFoundException alloc] init];
    }
    return userProfile;
}


@end
