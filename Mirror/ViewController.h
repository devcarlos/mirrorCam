//
//  ViewController.h
//  Mirror
//
//  Created by Carlos Alcala on 12/19/14.
//  Copyright (c) 2014 Kurrentap. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController : UIViewController <UIPopoverControllerDelegate>

//check control properties
@property (nonatomic) BOOL isHiddenControls;

// AVFoundation Properties
@property (strong, nonatomic) AVCaptureSession * mySesh;
@property (strong, nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) AVCaptureDevice * myDevice;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer * captureVideoPreviewLayer;

// Photo/Capture Properties
@property (strong, nonatomic) UIView *imageStreamV;
@property (strong, nonatomic) UIImageView *capturedImageV;
@property (strong, nonatomic) UITapGestureRecognizer *mirrorTap;
@property (strong, nonatomic) UIPopoverController *sharePopoverController;

//toolbar outlets
@property (weak, nonatomic) IBOutlet UIToolbar *toolBar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *shareButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;
@property (weak, nonatomic) IBOutlet UIButton *closeButton;


// Actions
- (void) capturePhoto;
//- (void) sharePhoto;
- (void) saveImageToPhotoAlbum;

- (IBAction)sharePhoto:(id)sender;
- (IBAction)savePhoto:(id)sender;
- (IBAction)closePhoto:(id)sender;

@end

