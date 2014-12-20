//
//  ViewController.m
//  Mirror
//
//  Created by Carlos Alcala on 12/19/14.
//  Copyright (c) 2014 Kurrentap. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
{
    // Measurements
    CGFloat screenWidth;
    CGFloat screenHeight;
    CGFloat topX;
    CGFloat topY;
    
    // Resize Toggles
    BOOL isImageResized;
    BOOL isSaveWaitingForResizedImage;
    
    // Capture Toggle
    BOOL isCapturingImage;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //check camera auth on iOS8
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
        // Pre iOS 8 -- No camera auth required.
        [self setup];
    }
    else {
        // iOS8
        
        // Thanks: http://stackoverflow.com/a/24684021/2611971
        AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        switch (status) {
            case AVAuthorizationStatusAuthorized:
                // Do setup early if possible.
                [self setup];
                break;
            default:
                break;
        }
        
    }
}


- (void) viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1) {
        // Pre iOS 8 -- No camera auth required.
        [self animateIntoView];
    }
    else {
        __block UIAlertView *alert = nil;
        // iOS 8
        AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        switch (status) {
            case AVAuthorizationStatusDenied:
            case AVAuthorizationStatusRestricted:
                NSLog(@"Not authorized or restricted");
                
                //show error alert
                alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Not authorized or restricted, please try again." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
                [alert show];
                
                break;
            case AVAuthorizationStatusAuthorized:
                [self animateIntoView];
                break;
            case AVAuthorizationStatusNotDetermined: {
                // not determined
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                    if(granted){
                        [self setup];
                        [self animateIntoView];
                    } else {
                        //show error alert
                        alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Not authorized or restricted, please try again." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
                        [alert show];
                        
                        //finish and clean up everything to avoid any crashes
                        [self cleanupCameraSession];
                    }
                }];
            }
            default:
                break;
        }
    }
}


- (void) animateIntoView
{
    [UIView animateWithDuration:.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        _imageStreamV.alpha = 1;
    } completion:^(BOOL finished) {
        //nothing to do just continue
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    NSLog(@"DID RECEIVE MEMORY WARNING");
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}


#pragma mark - CAMARA SETUP

- (void) setup {
    
    self.view.clipsToBounds = NO;
    self.view.backgroundColor = [UIColor blackColor];
    
    /*
     The layout has shifted in iOS 8 causing problems.  
     I realize that this isn't the best solution, but it is the working solution for
     a 2 days max time frame to handle this app.
     */
    CGRect screen = [UIScreen mainScreen].bounds;
    CGFloat currentWidth = CGRectGetWidth(screen);
    CGFloat currentHeight = CGRectGetHeight(screen);
    screenWidth = currentWidth < currentHeight ? currentWidth : currentHeight;
    screenHeight = currentWidth < currentHeight ? currentHeight : currentWidth;
    
    if (_imageStreamV == nil) _imageStreamV = [[UIView alloc]init];
    _imageStreamV.alpha = 0;
    _imageStreamV.frame = self.view.bounds;
    
    if (_capturedImageV == nil) _capturedImageV = [[UIImageView alloc]init];
    _capturedImageV.frame = _imageStreamV.frame; // just to even it out
    _capturedImageV.backgroundColor = [UIColor clearColor];
    _capturedImageV.userInteractionEnabled = YES;
    _capturedImageV.contentMode = UIViewContentModeScaleAspectFill;
    
    //insert subviews below toolbar to display later
    [self.view insertSubview:_capturedImageV belowSubview:self.toolBar];
    [self.view insertSubview:_imageStreamV belowSubview:_capturedImageV];
    
    //tap gesture here
    _mirrorTap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(toogleCapturePhoto)];
    _mirrorTap.numberOfTapsRequired = 1;
    
    //add tap gesture
    [_capturedImageV addGestureRecognizer:_mirrorTap];
    
    // SETTING UP CAM
    if (_mySesh == nil) _mySesh = [[AVCaptureSession alloc] init];
    _mySesh.sessionPreset = AVCaptureSessionPresetPhoto;
    
    _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_mySesh];
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _captureVideoPreviewLayer.frame = _imageStreamV.layer.bounds; // parent of layer
    
    [_imageStreamV.layer addSublayer:_captureVideoPreviewLayer];
    
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    if (devices.count==0) {
        NSLog(@"Error: No devices found with camera (like simulator)");
        
        //show alert about not camera found
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"No devices found with camera." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [alert show];

        return;
    }
    
    ///////////////////////////////////
    // rear camera: 0 front camera: 1
    ///////////////////////////////////
    
    //check front camera is available
    if ([[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 1) {
        //FRONT camera
        _myDevice = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo][1];
    } else {
        //REAR camera
        _myDevice = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo][0];
    }
    
    //turn flass off
    if ([_myDevice isFlashAvailable] && _myDevice.flashActive && [_myDevice lockForConfiguration:nil]) {
        NSLog(@"Turning Flash Off");
        _myDevice.flashMode = AVCaptureFlashModeOff;
        [_myDevice unlockForConfiguration];
    }
    
    NSError * error = nil;
    AVCaptureDeviceInput * input = [AVCaptureDeviceInput deviceInputWithDevice:_myDevice error:&error];
    
    if (!input) {
        // Handle the error appropriately.
        NSLog(@"ERROR: trying to open camera: %@", error);
        
        NSString *errorMsg = [NSString stringWithFormat:@"Error: trying with camera input: %@", error];
        
        //show alert about error with camera input
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:errorMsg delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [alert show];
        
        return;
    }
    
    [_mySesh addInput:input];
    
    _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary * outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    [_stillImageOutput setOutputSettings:outputSettings];
    [_mySesh addOutput:_stillImageOutput];
    
    
    [_mySesh startRunning];
    
    //hide controls when displaying camera
    [self hideControls];
}

- (void)hideControls {
    //use animation to hide
    [UIView animateWithDuration:.5 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.toolBar.alpha = 0;
        self.closeButton.alpha = 0;
        self.toolBar.hidden = YES;
        self.closeButton.hidden = YES;
    } completion:nil];
    
    _isHiddenControls = YES;
}

- (void)showControls {
    
    //use animation to show
    self.toolBar.hidden = NO;
    self.closeButton.hidden = NO;
    
    [UIView animateWithDuration:0.75 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.toolBar.alpha = 1;
        self.closeButton.alpha = 1;
    } completion:nil];

    _isHiddenControls = NO;
}

- (void) toogleCapturePhoto {
    
    //check hidden controls to capture photo or hide controls
    if (_isHiddenControls) {
        [self capturePhoto];
    } else {
        [self showCamera];
    }
}

- (void) showCamera {
    [self hideControls];
    [self cleanCaptureView];
}

- (void) capturePhoto {
    if (isCapturingImage) {
        return;
    }
    if (!_isHiddenControls) {
        return;
    }

    isCapturingImage = YES;
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in _stillImageOutput.connections)
    {
        for (AVCaptureInputPort *port in [connection inputPorts])
        {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] )
            {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) { break; }
    }
    
    [_stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error)
     {
         if(!CMSampleBufferIsValid(imageSampleBuffer))
         {
             return;
         }
         NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
         
         UIImage * capturedImage = [[UIImage alloc]initWithData:imageData scale:1];
         
         //show photo preview and release imageData
         isCapturingImage = NO;
         isImageResized = NO;
         _capturedImageV.image = capturedImage;
         imageData = nil;
         
         //show controls
         [self showControls];
     }];
}

#pragma mark - RESIZE IMAGE

- (void) resizeImage {
    
    // Set Size
    CGSize size = CGSizeMake(screenWidth, screenHeight);
    
    // Set Draw Rect
    CGRect drawRect = ({
        // targetWidth is the width our image would need to be at the current screenheight if we maintained the image ratio.
        CGFloat targetWidth = screenHeight * 0.75; // 3:4 ratio
        
        // we have to draw around the context of the screen
        // our final image will be the image that is left in the frame of the context
        // by drawing outside it, we remove the edges of the picture
        CGFloat offsetTop = (screenHeight - size.height) / 2;
        CGFloat offsetLeft = (targetWidth - size.width) / 2;
        CGRectMake(-offsetLeft, -offsetTop, targetWidth, screenHeight);
    });
    
    // START CONTEXT
    UIGraphicsBeginImageContextWithOptions(size, YES, 2.0);
    [_capturedImageV.image drawInRect:drawRect];
    _capturedImageV.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    // END CONTEXT
    
    isImageResized = YES;
}

#pragma mark CLEAN CAPTURE IMAGE AND SETTINGS

- (void) cleanCaptureView {
    if (_capturedImageV.image) {
        _capturedImageV.contentMode = UIViewContentModeScaleAspectFill;
        _capturedImageV.backgroundColor = [UIColor clearColor];
        _capturedImageV.image = nil;
        
        isImageResized = NO;
        isSaveWaitingForResizedImage = NO;
    }
}

- (void) cleanupCameraSession {
    
    // Clean Up
    isImageResized = NO;
    isSaveWaitingForResizedImage = NO;
    
    [_mySesh stopRunning];
    _mySesh = nil;
    
    _capturedImageV.image = nil;
    [_capturedImageV removeFromSuperview];
    _capturedImageV = nil;
    
    [_imageStreamV removeFromSuperview];
    _imageStreamV = nil;
    
    _stillImageOutput = nil;
    _myDevice = nil;
}

#pragma mark - SAVE PHOTO

- (void)saveImageToPhotoAlbum {
    UIImageWriteToSavedPhotosAlbum(_capturedImageV.image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    
    if (error != NULL) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error!" message:@"Image couldn't be saved" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [alert show];
    }
}

#pragma mark - SHARE PHOTO

- (void)sharePhotoImage {
    
    UIImage *shareImage = _capturedImageV.image;
    
    NSArray *items = @[shareImage];
    
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    
    //check to display Popover on iPad or present view on iPhone
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {//iPad
        
        //iOS8 fix sourceview for Popover
        if ([activity respondsToSelector:@selector(popoverPresentationController)] ) {
            activity.popoverPresentationController.sourceView = self.view;
        }
        
        //if already displayed dismiss
        if (self.sharePopoverController.popoverVisible) {
            [self.sharePopoverController dismissPopoverAnimated:YES];
            return;
        }

        //init if not already
        if (!self.sharePopoverController) {
            self.sharePopoverController = [[UIPopoverController alloc] initWithContentViewController:activity];
        }
        
        //setup delegate + passtrough
        self.sharePopoverController.delegate = self;
        self.sharePopoverController.passthroughViews = @[self.shareButton];
        
        //display the popover on iPad from BarButtonItem
        [self.sharePopoverController presentPopoverFromBarButtonItem:self.shareButton
                                            permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];

    } else {//iPhone
        
        //iPhone just display activity controller
        [self presentViewController:activity animated:YES completion:nil];
        
    }
}

#pragma mark - Popover controller delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    //reset popover
    self.sharePopoverController = nil;
}

#pragma mark - BUTTON ACTIONS

- (IBAction)sharePhoto:(id)sender {
    //display share activity popover
    [self sharePhotoImage];
}

- (void) savePhotoResized {
    
    //first time resize to avoid memory issues
    if (!isImageResized) {
        isSaveWaitingForResizedImage = YES;
        [self resizeImage];
    }
    
    //save image resized to photos album
    [self saveImageToPhotoAlbum];
    
}

- (IBAction)savePhoto:(id)sender {
    [self savePhotoResized];
}

- (IBAction)closePhoto:(id)sender {
    //show camera and hide controls
    [self showCamera];
}

@end
