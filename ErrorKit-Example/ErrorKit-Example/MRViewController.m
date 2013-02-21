// MRViewController.m
//
// Copyright (c) 2013 Héctor Marqués
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MRViewController.h"
#import "ErrorKit.h"
#import "MRRecoveryAttempter.h"


@interface MRViewController () {
    NSMutableSet *_trustedDomains;
}

@end

@implementation MRViewController

- (NSMutableSet *)trustedDomains
{
    if (_trustedDomains == nil) {
        _trustedDomains = NSMutableSet.new;
    }
    return _trustedDomains;
}

#pragma mark - IBAction methods

- (IBAction)connectAction:(id)sender
{
    [self.view endEditing:YES];
    if (sender) {
        self.responseTextView.text = NSLocalizedString(@"Connecting...", nil);
    } else {
        self.responseTextView.text = NSLocalizedString(@"Retrying...", nil);
    }
    NSURL *url = [NSURL URLWithString:self.urlTextField.text];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [NSURLConnection connectionWithRequest:request delegate:self];
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    MRLogError(error);
    self.responseTextView.text = NSLocalizedString(@"Connection failed", nil);
    MRRecoveryAttempter *attempter = [[MRRecoveryAttempter alloc] initWithBlock:^BOOL(NSError *error, NSUInteger recoveryOption) {
        if (recoveryOption == 0) {
            NSURL *failingURL = [NSURL URLWithString:error.failingURLString];
            if (error.code == NSURLErrorServerCertificateUntrusted) {
                [self.trustedDomains addObject:failingURL.host];
            }
            [self connectAction:nil];
            return YES;
        }
        return NO;
    }];
    if (error.code == NSURLErrorServerCertificateUntrusted) {
        MRErrorBuilder *builder = [MRErrorBuilder builderWithError:error];
        builder.recoveryAttempter = attempter;
        builder.localizedRecoveryOptions = @[ NSLocalizedString(@"YES", nil) ];
        [[UIAlertView alertWithTitle:nil error:builder.error] show];
    } else if (error.code == NSURLErrorNotConnectedToInternet) {
        MRErrorBuilder *builder = [MRErrorBuilder builderWithError:error];
        builder.recoveryAttempter = attempter;
        builder.localizedRecoverySuggestion = NSLocalizedString(@"Please check your internet connection and try again.", nil);
        builder.helpAnchor = NSLocalizedString(@"You can adjust cellular network settings on iPhone in Settings > General > Cellular. On iPad the settings are located in Settings > Cellular Data\n\nTo locate nearby Wi-Fi networks, tap Settings > Wi-Fi", nil);
        builder.localizedRecoveryOptions = @[ NSLocalizedString(@"Retry", nil) ];
        [[UIAlertView alertWithTitle:nil error:builder.error] show];
    } else if (!error.isCancelledError) {
        [[UIAlertView alertWithTitle:nil error:error] show];
    }
}

#pragma mark - NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSString *responseUTF8String = [NSString stringWithUTF8String:data.bytes];
    if (responseUTF8String.length > 0) {
        self.responseTextView.text = responseUTF8String;
    } else {
        self.responseTextView.text = [data description];
    }
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([self.trustedDomains containsObject:challenge.protectionSpace.host]) {
			NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
			[challenge.sender useCredential:credential forAuthenticationChallenge:challenge];
    } else {
        [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
    }
}

#pragma mark - UIViewController methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.connectButton setTitle:NSLocalizedString(@"Connect", nil) forState:UIControlStateNormal];
}

@end