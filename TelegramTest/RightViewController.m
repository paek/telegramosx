//
//  RightViewController.m
//  TelegramTest
//
//  Created by Dmitry Kondratyev on 10/29/13.
//  Copyright (c) 2013 keepcoder. All rights reserved.
//

#import "RightViewController.h"
#import "MessagesViewController.h"
#import "Telegram.h"
#import "NotSelectedDialogsViewController.h"
#import "NSView-DisableSubsAdditions.h"
#import "NSAlertCategory.h"
#import "MessageTableItem.h"
#import "DraggingControllerView.h"
#import "TMMediaUserPictureController.h"
#import "TMCollectionPageController.h"
#import "TMAudioRecorder.h"

@implementation TMView (Dragging)




-(NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {

    if([Telegram rightViewController].messagesViewController.dialog && [Telegram rightViewController].navigationViewController.currentController == [Telegram rightViewController].messagesViewController) {
        NSPasteboard *pst = [sender draggingPasteboard];
        
        if(![pst.name isEqualToString:TGImagePType] && ( [[pst types] containsObject:NSFilenamesPboardType] || [[pst types] containsObject:NSTIFFPboardType])) {
            if([[pst types] containsObject:NSFilenamesPboardType]) {
                NSArray *files = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
                

                
                if(files.count == 1 && ![mediaTypes() containsObject:[[files[0] pathExtension] lowercaseString]]) {
                     [DraggingControllerView setType:DraggingTypeSingleChoose];
                } else {
                    [DraggingControllerView setType:DraggingTypeMultiChoose];
                }
            }
            
            
            [self addSubview:[DraggingControllerView view]];
            
        }
    }
    
    
    return NSDragOperationNone;
}




-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    
    [MessageSender sendDraggedFiles:sender dialog:[Telegram rightViewController].messagesViewController.dialog asDocument:NO];
    
    return YES;
}

@end

@interface RightViewController ()
@property (nonatomic, strong) NSView *lastView;
@property (nonatomic, strong) NSView *currentView;

@property (nonatomic, strong) TMViewController *noDialogsSelectedViewController;
@property (nonatomic, strong) TMView *modalView;
@property (nonatomic, strong) id modalObject;
//@property (nonatomic, strong) TMNavigationController *navigationView;

@end

@implementation RightViewController

- (id)init {
    self = [super init];
    if(self) {

    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        // Initialization code here.
       
    }
    return self;
}

-(BOOL)becomeFirstResponder {
    [self.messagesViewController becomeFirstResponder];
    return YES;
}
-(BOOL)acceptsFirstResponder {
    return YES;
}

- (void) loadView {
    [super loadView];
    
    self.navigationViewController = [[TMNavigationController alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.navigationViewController.view];
    
    [self.view setBackgroundColor:[NSColor whiteColor]];
    [self.view setAutoresizesSubviews:YES];
    [self.view setAutoresizingMask:NSViewHeightSizable | NSViewWidthSizable];
    
    [self.view registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType,NSStringPboardType, nil]];
    
    [Notification addObserver:self selector:@selector(logout:) name:LOGOUT_EVENT];
    
    self.messagesViewController = [[MessagesViewController alloc] initWithFrame:self.view.bounds];
    self.userInfoViewController = [[UserInfoViewController alloc] initWithFrame:self.view.bounds];
    self.chatInfoViewController = [[ChatInfoViewController alloc] initWithFrame:self.view.bounds];
    self.collectionViewController = [[TMCollectionPageController alloc] initWithFrame:self.view.bounds];
    self.noDialogsSelectedViewController = [[NotSelectedDialogsViewController alloc] initWithFrame:self.view.bounds];
    self.broadcastInfoViewController = [[BroadcastInfoViewController alloc] initWithFrame:self.view.bounds];
    
    
    [self.navigationViewController pushViewController:self.messagesViewController animated:NO];
    [self.navigationViewController pushViewController:self.userInfoViewController animated:NO];
    [self.navigationViewController pushViewController:self.chatInfoViewController animated:NO];
    [self.navigationViewController pushViewController:self.collectionViewController animated:NO];
    [self.navigationViewController clear];

    [self.navigationViewController pushViewController:self.noDialogsSelectedViewController animated:NO];
    [self.navigationViewController.view.window makeFirstResponder:nil];
}

- (void)navigationGoBack {
    if([[TMAudioRecorder sharedInstance] isRecording])
        return;
    
    [self hideModalView:YES animation:NO];
    
    [[[Telegram sharedInstance] firstController] closeAllPopovers];
       
    
    [self.navigationViewController goBackWithAnimation:YES];
}



- (void)hideModalView:(BOOL)isHide animation:(BOOL)animated {
    
    if(isHide) {
        dispatch_block_t block = ^{
            [self.modalView removeFromSuperview];
            [self.navigationViewController.view enableSubViews];
            self.modalView = nil;
            self.modalObject = nil;
            [Notification perform:@"MODALVIEW_VISIBLE_CHANGE" data:nil];

        };
        
        if(animated) {
            [CATransaction begin];
            {
                [CATransaction setCompletionBlock:block];
                
                CABasicAnimation *flash = [CABasicAnimation animationWithKeyPath:@"opacity"];
                flash.fromValue = [NSNumber numberWithFloat:0.95];
                flash.toValue = [NSNumber numberWithFloat:0];
                flash.duration = 0.16;
                flash.autoreverses = NO;
                flash.repeatCount = 0;
                [self.modalView.layer removeAllAnimations];
                self.modalView.layer.opacity = 0;
                
                [self.modalView.layer addAnimation:flash forKey:@"flashAnimation"];
            }
            
            [CATransaction commit];
        } else {
            block();
        }
        
       
    } else {
        [self.modalView removeFromSuperview];
        [self.navigationViewController.view disableSubViews];
        [self.modalView setFrame:self.view.bounds];

        [self.view addSubview:self.modalView];
        
        if(animated) {
            CABasicAnimation *flash = [CABasicAnimation animationWithKeyPath:@"opacity"];
            flash.fromValue = [NSNumber numberWithFloat:0.0];
            flash.toValue = [NSNumber numberWithFloat:0.95];
            flash.duration = 0.16;
            flash.autoreverses = NO;
            flash.repeatCount = 0;
            [self.modalView.layer removeAllAnimations];
            self.modalView.layer.opacity = 0.95;
            
            [self.modalView.layer addAnimation:flash forKey:@"flashAnimation"];
            
            [[NSCursor arrowCursor] set];
        }
    }
}

- (void)modalViewSendAction:(id)object {
    
    TL_conversation *dialog = object;
    if(dialog.type == DialogTypeSecretChat) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSInformationalAlertStyle];
        [alert setMessageText:NSLocalizedString(@"Alert.Error", nil)];
        NSString *informativeText;
        if(self.modalView == [self shareContactModalView]) {
            informativeText = NSLocalizedString(@"Conversation.CantShareContactToSecretChat", nil);
        } else {
            informativeText = NSLocalizedString(@"Conversation.CantForwardSecretMessages", nil);
        }
        [alert setInformativeText:informativeText];
        [alert show];
        return;
    }
    
    if(dialog.type == DialogTypeBroadcast && self.modalView == [self forwardModalView]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSInformationalAlertStyle];
        [alert setMessageText:NSLocalizedString(@"Alert.Error", nil)];
        [alert setInformativeText: NSLocalizedString(@"Conversation.CantForwardToBroadcast", nil)];
        [alert show];
        return;
    }
    
    if(self.modalView == [self shareContactModalView]) {
        TGUser *modalObject = self.modalObject;
        
        if(modalObject && modalObject.phone) {
            
            [self.messagesViewController shareContact:modalObject conversation:dialog callback:^{
                [[Telegram sharedInstance] showMessagesFromDialog:dialog sender:self];
            }];
            
           
            //[MessageSender shareContact:media dialog:dialog];
        }
        
        
    } else {
        
        NSMutableArray *messages = [self.messagesViewController selectedMessages];
        NSMutableArray *ids = [[NSMutableArray alloc] init];
        for(MessageTableItem *item in messages)
            [ids addObject:item.message];
        
        [ids sortUsingComparator:^NSComparisonResult(TGMessage * a, TGMessage * b) {
            return a.n_id > b.n_id ? NSOrderedDescending : NSOrderedAscending;
        }];
        
        [self.messagesViewController cancelSelectionAndScrollToBottom];
        weakify();
        
        
        
        dialog.last_marked_date = [[MTNetwork instance] getTime]+1;
        dialog.last_marked_message = dialog.top_message;
        
        [dialog save];
        
        self.messagesViewController.didUpdatedTable = ^ {
            
            strongSelf.messagesViewController.didUpdatedTable = nil;
            
            [strongSelf.messagesViewController forwardMessages:ids conversation:dialog callback:^{
                    
                
            }];
        };
        
        if(self.messagesViewController.dialog == dialog) {
            self.messagesViewController.didUpdatedTable();
        }
        
        [[Telegram sharedInstance] showMessagesFromDialog:dialog sender:self];
        
       
        
       
        
    }
    
    [self hideModalView:YES animation:YES];
}




- (void)showShareContactModalView:(TGUser *)user {
    [self hideModalView:YES animation:NO];
    
    [self.navigationViewController.view setAcceptsTouchEvents:NO];
    
    TMModalView *view = [self shareContactModalView];
    
    self.modalView = view;
    self.modalObject = user;
    
    [view removeFromSuperview];
    [view setFrameSize:view.bounds.size];
    [view setHeaderTitle:NSLocalizedString(@"Messages.SharingContact", nil) text:[NSString stringWithFormat:NSLocalizedString(@"Conversation.SelectToShareContact", nil), user.fullName]];
    
    [self hideModalView:NO animation:YES];
}

- (void)showForwardMessagesModalView:(TL_conversation *)dialog messagesCount:(NSUInteger)messagesCount {
    [self hideModalView:YES animation:NO];
    
    [self.navigationViewController.view setAcceptsTouchEvents:NO];
    
    TMModalView *view = [self forwardModalView];
    
    self.modalView = view;
    self.modalObject = dialog;
    
    [view removeFromSuperview];
    [view setFrameSize:view.bounds.size];
    
    NSString *messageOrMessages = messagesCount == 1 ? NSLocalizedString(@"message", nil) : NSLocalizedString(@"messages", nil);
    
    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Message.Action.Forwarding", nil)];
    if(messagesCount == 1) {
        title = [NSString stringWithFormat:@"%@ %@", title, messageOrMessages];
    } else {
        title = [NSString stringWithFormat:@"%@ %lu %@", title, (unsigned long)messagesCount, messageOrMessages];
    }
    
    NSString *name;
    if(dialog.type == DialogTypeChat) {
        name = dialog.chat.title;
    } else if(dialog.type == DialogTypeSecretChat) {
        name = dialog.encryptedChat.peerUser.fullName;
    } else {
        name = dialog.user.fullName;
    }
    
    [view setHeaderTitle:title text:[NSString stringWithFormat:NSLocalizedString(messagesCount == 1 ?  @"Conversation.SelectToForward" : @"Conversation.SelectToForwards", nil), name]];
    
    [self hideModalView:NO animation:YES];
}

- (TMModalView *)forwardModalView {
    static TMModalView *view;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        view = [[TMModalView alloc] initWithFrame:self.view.bounds];
    });
    return view;
}


- (TMModalView *)shareContactModalView {
    static TMModalView *view;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        view = [[TMModalView alloc] initWithFrame:self.view.bounds];
    });
    return view;
}

- (void)dealloc {
    [Notification removeObserver:self];
}

- (void)showNotSelectedDialog {
    [self hideModalView:YES animation:NO];
    [self.navigationViewController pushViewController:self.noDialogsSelectedViewController animated:YES];
}

- (void)logout:(NSNotification *)notify {
    [self.messagesViewController drop];
}

- (void)showByDialog:(TL_conversation *)dialog sender:(id)sender {
    [self showByDialog:dialog withJump:0 historyFilter:[HistoryFilter class] sender:sender];
}


- (BOOL)showByDialog:(TL_conversation *)dialog withJump:(int)messageId historyFilter:(Class )filter sender:(id)sender  {
    if(self.navigationViewController.currentController == self.messagesViewController && self.messagesViewController.dialog.peer.peer_id == dialog.peer.peer_id)
        return NO;
    
    [self hideModalView:YES animation:NO];
    
    if(self.messagesViewController.dialog == dialog && self.navigationViewController.currentController != self.messagesViewController) {
        [self.messagesViewController setCurrentConversation:dialog withJump:messageId historyFilter:filter];
        [self.navigationViewController goBackWithAnimation:YES];
    } else {
        
        [self.messagesViewController setCurrentConversation:dialog withJump:messageId historyFilter:filter];
        
        [self.navigationViewController.viewControllerStack removeAllObjects];
        [self.navigationViewController.viewControllerStack addObject:self.noDialogsSelectedViewController];
        
        [self.navigationViewController pushViewController:self.messagesViewController animated:self.navigationViewController.currentController == self.userInfoViewController];
    }

    return YES;
}

- (void)showUserInfoPage:(TGUser *)user conversation:(TL_conversation *)conversation {
    if(self.navigationViewController.currentController == self.userInfoViewController && self.userInfoViewController.user.n_id == user.n_id)
        return;
    
    if([user isKindOfClass:[TL_userEmpty class]])
        return;
    
    [self hideModalView:YES animation:NO];

    
    [self.userInfoViewController setUser:user conversation:conversation];
    [self.navigationViewController pushViewController:self.userInfoViewController animated:YES];
}



- (void)showUserInfoPage:(TGUser *)user  {
    [self showUserInfoPage:user conversation:user.dialog];
}

- (void)showCollectionPage:(TL_conversation *)conversation {
    if(self.navigationViewController.currentController == self.collectionViewController && self.collectionViewController.conversation.peer.peer_id == conversation.peer.peer_id)
        return;
    
    [self hideModalView:YES animation:NO];
    
    [self.collectionViewController setConversation:conversation];
    
    [self.navigationViewController pushViewController:self.collectionViewController animated:YES];
    
}

- (void)showBroadcastInfoPage:(TL_broadcast *)broadcast {
    if(self.navigationViewController.currentController == self.chatInfoViewController && self.chatInfoViewController.chat.n_id == broadcast.n_id)
        return;
    
    
    [self hideModalView:YES animation:NO];
    
    [self.broadcastInfoViewController setBroadcast:broadcast];
    [self.navigationViewController pushViewController:self.broadcastInfoViewController animated:YES];
}


- (void)showChatInfoPage:(TGChat *)chat {
    if(self.navigationViewController.currentController == self.chatInfoViewController && self.chatInfoViewController.chat.n_id == chat.n_id)
        return;
    
    if(chat.type != TGChatTypeNormal)
        return;
    
    
    [self hideModalView:YES animation:NO];
    
    [self.chatInfoViewController setChat:chat];
    [self.navigationViewController pushViewController:self.chatInfoViewController animated:YES];
}

- (BOOL)isActiveDialog {
    return self.navigationViewController.currentController == self.messagesViewController;
}

- (BOOL)isModalViewActive {
    return self.modalView != nil;
}

@end
