// GiCmdController.mm
// Copyright (c) 2012, Zhang Yungui <rhcad@hotmail.com>
// License: LGPL, https://github.com/rhcad/touchvg

#import "GiCmdController.h"
#import "GiEditAction.h"
#import "GiViewController.h"
#include <mgselect.h>
#include <vector>
#include <ioscanvas.h>
#include <mgbasicsp.h>

@interface GiCommandController()

- (BOOL)setView:(UIView*)view;
- (void)convertPoint:(CGPoint)pt;
- (BOOL)getPointForPressDrag:(UIGestureRecognizer *)sender :(CGPoint*)point;
- (GiContext*)currentContext;
- (bool)showActions:(int)selState :(const int*)actions :(const Box2d*)selbox;
- (IBAction)onContextAction:(id)sender;
- (BOOL)handleSelectionTwoFingers:(UIGestureRecognizer *)sender;

@end

static NSMutableArray* _buttons = nil;

class MgViewProxy : public MgView
{
private:
    GiCommandController*    _owner;
    id<GiView>      _curview;
    id<GiView>      _mainview;
    UIView**        _auxviews;
    UIImage*        _pointImages[2];
    
public:
    BOOL            _dynChanged;
    BOOL            _lockVertex;
    
    MgViewProxy(GiCommandController* owner, UIView** views) : _owner(owner)
        , _curview(Nil), _mainview(Nil), _auxviews(views)
        , _dynChanged(NO), _lockVertex(false)
    {
        _pointImages[0] = nil;
        _pointImages[1] = nil;
    }
    
    ~MgViewProxy() {
        [_pointImages[0] release];
        [_pointImages[1] release];
        [_buttons release];
        _buttons = nil;
    }
    
    id<GiView> getView() { return _curview; }
    id<GiView> getMainView() { return _mainview; }
    
    void setView(id<GiView> gv) {
        _curview = gv;
        if (!_mainview) {
            _mainview = gv;
        }
    }
    
    bool isMagnifierVisible() {
        return _auxviews[0] && !_auxviews[0].hidden && !_auxviews[0].superview.hidden;
    }
    
    MgShapes* shapes() { return [_curview shapes]; }
    GiTransform* xform() { return [_curview xform]; }
    GiGraphics* graph() { return [_curview graph]; }
    
private:
    
    bool shapeWillAdded(MgShape* shape) {
        return (![_owner.editDelegate respondsToSelector:@selector(shapeWillAdded)]
                || [_owner.editDelegate performSelector:@selector(shapeWillAdded)]);
    }
    bool shapeWillDeleted(MgShape* shape) {
        return (![_owner.editDelegate respondsToSelector:@selector(shapeWillDeleted)]
                || [_owner.editDelegate performSelector:@selector(shapeWillDeleted)]);
    }
    bool shapeCanRotated(MgShape*) {
        return (![_owner.editDelegate respondsToSelector:@selector(shapeCanRotated)]
                || [_owner.editDelegate performSelector:@selector(shapeCanRotated)]);
    }
    bool shapeCanTransform(MgShape*) {
        return (![_owner.editDelegate respondsToSelector:@selector(shapeCanTransform)]
                || [_owner.editDelegate performSelector:@selector(shapeCanTransform)]);
    }
    
    void regen() {
        [_mainview regen];
        for (int i = 0; _auxviews[i]; i++) {
            if ([_auxviews[i] respondsToSelector:@selector(regen)]
                && !_auxviews[i].hidden) {
                [_auxviews[i] performSelector:@selector(regen)];
            }
        }
        if (MgDynShapeLock::lockedForWrite()) {
            _dynChanged = YES;
        }
    }
    
    void redraw(bool fast) {
        [_curview redraw:fast];
        
        if (MgDynShapeLock::lockedForWrite()) {
            _dynChanged = YES;
        }
    }
    
    void shapeAdded(MgShape* shape) {
        [_mainview shapeAdded:shape];
        for (int i = 0; _auxviews[i]; i++) {
            if ([_auxviews[i] conformsToProtocol:@protocol(GiView)]
                && !_auxviews[i].hidden) {
                id<GiView> gv = (id<GiView>)_auxviews[i];
                [gv shapeAdded:shape];
            }
        }
        if ([_owner.editDelegate respondsToSelector:@selector(shapeAdded)]) {
            [_owner.editDelegate performSelector:@selector(shapeAdded)];
        }
    }
    
    bool isContextActionsVisible() {
        return _buttons && [_buttons count] > 0;
    }
    
    bool showContextActions(int selState, const int* actions, const Box2d& selbox) {
        return [_owner showActions:selState :actions :&selbox];
    }
    
    bool drawHandle(GiGraphics* gs, const Point2d& pnt, bool hotdot) {
        int index = hotdot ? 1 : 0;
        GiCanvasIos* canvas = (GiCanvasIos*)gs->getCanvas();
        
        if (!_pointImages[index]) {
            _pointImages[index] = [UIImage imageNamed:hotdot ? @"vgdot2.png" : @"vgdot1.png"];
            [_pointImages[index] retain];
        }
        if (_pointImages[index]) {
            canvas->drawImage([_pointImages[index] CGImage], pnt);
        }
        
        return _pointImages[index];
    }
};

static long s_cmdRef = 0;

@implementation GiActionParams
@synthesize selstate, actions, selbox, view, buttons;
@end

@implementation GiCommandController

- (BOOL)setView:(UIView*)view
{
    if ([view conformsToProtocol:@protocol(GiView)])
        _mgview->setView((id<GiView>)view);
    return !!_mgview->getView();
}

- (void)convertPoint:(CGPoint)pt
{
    _motion->point = Point2d(pt.x, pt.y);
    _motion->pointM = Point2d(pt.x, pt.y) * _motion->view->xform()->displayToModel();
}

- (BOOL)getPointForPressDrag:(UIGestureRecognizer *)sender :(CGPoint*)point
{
    BOOL valid = ([sender numberOfTouches] >= _touchCount);
    
    if (valid) {
        *point = [sender locationOfTouch:0 inView:sender.view];
        float dist = mgHypot(point->x - _motion->startPoint.x, point->y - _motion->startPoint.y);
    
        if ([sender numberOfTouches] > 1) {
            CGPoint pt = [sender locationOfTouch:1 inView:sender.view];
            float dist2 = mgHypot(pt.x - _motion->startPoint.x, pt.y - _motion->startPoint.y);
            if (dist2 > dist)
                *point = pt;
        }
    }
    
    return valid;
}

- (GiContext*)currentContext
{
    MgShape* shape = NULL;
    mgGetCommandManager()->getSelection(_mgview, 1, &shape, false);
    return shape ? shape->context() : _mgview->context();
}

+ (void)hideContextActions
{
    if (_buttons) {
        for (UIView *button in _buttons) {
            [button removeFromSuperview];
        }
        [_buttons removeAllObjects];
    }
}

- (void)doContextAction:(int)action
{
    mgGetCommandManager()->doContextAction(_motion, action);
}

- (IBAction)onContextAction:(id)sender
{
    UIView *btn = (UIView *)sender;
    mgGetCommandManager()->doContextAction(_motion, btn.tag);
    [GiCommandController hideContextActions];
}

- (bool)showActions:(int)selState :(const int*)actions :(const Box2d*)selbox
{
    if (!_buttons) {
        _buttons = [[NSMutableArray alloc]init];
    }
    if (!actions) {
        for (UIView *button in _buttons) {
            [button removeFromSuperview];
        }
        [_buttons removeAllObjects];
        return false;
    }
    if ([_buttons count] > 0 && _motion->pressDrag) {
        return false;
    }
    
    UIView *view = [_mgview->getView() ownerView];
    bool handled = false;
    
    if ([editDelegate respondsToSelector:@selector(showContextActions:)]) {
        GiActionParams *params = [[GiActionParams alloc]init];
        params.selstate = selState;
        params.actions = actions;
        params.selbox = CGRectMake(selbox->xmin, selbox->ymin, selbox->width(), selbox->height());
        params.view = view;
        params.buttons = _buttons;        
        handled = ![editDelegate performSelector:@selector(showContextActions:) withObject:params];
        [params release];
        if (handled)
            return true;
    }
    
    NSString* captions[] = { nil, @"全选", @"重选", @"绘图", @"取消",
        @"删除", @"克隆", @"剪开", @"定长", @"取消定长", @"锁定", @"解锁", 
        @"编辑顶点", @"隐藏顶点", @"闭合", @"不闭合", @"加点", @"删点" };
    
    CGPoint pt = CGPointMake(_motion->point.x - 40, _motion->point.y - 60);
    
    for (int i = 0; actions[i] > 0; i++) {
        if (actions[i] > 0 && actions[i] < sizeof(captions)/sizeof(captions[0])) {
            CGRect rect = CGRectMake(pt.x, pt.y, 80, 36);
            UIButton *btn = [[UIButton alloc]initWithFrame:rect];
            
            btn.tag = actions[i];
            btn.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.8];
            [btn addTarget:self action:@selector(onContextAction:) forControlEvents:UIControlEventTouchUpInside];
            [btn setTitle:captions[actions[i]] forState: UIControlStateNormal];
            pt.y -= rect.size.height;
            
            [view addSubview:btn];
            [_buttons addObject:btn];
            [btn release];
        }
    }
    
    return [_buttons count] > 0;
}

@synthesize editDelegate;
@synthesize commandName;
@synthesize currentShapeFixedLength;
@synthesize lineWidth;
@synthesize lineStyle;
@synthesize lineColor;
@synthesize fillColor;
@synthesize autoFillColor;
@synthesize dragging;

- (id)initWithViews:(UIView**)auxviews
{
    self = [super init];
    if (self) {
        _mgview = new MgViewProxy(self, auxviews);
        _motion = new MgMotion;
        _motion->view = _mgview;
        s_cmdRef++;
    }
    return self;
}

- (void)dealloc
{
    if (--s_cmdRef == 0) {
        mgGetCommandManager()->unloadCommands();
    }
    delete _motion;
    delete _mgview;
    [super dealloc];
}

- (const char*)commandName {
    return mgGetCommandManager()->getCommandName();
}

- (void)setCommandName:(const char*)name {
    mgGetCommandManager()->setCommand(_motion, name);
}

- (BOOL)dragging {
    return _motion->dragging;
}

- (float)lineWidth {
    return [self currentContext]->getLineWidth();
}

- (void)setLineWidth:(float)w {
    UInt32 n = mgGetCommandManager()->getSelection(_mgview, 0, NULL, true);
    std::vector<MgShape*> shapes(n, NULL);
    
    if (n > 0 && mgGetCommandManager()->getSelection(_mgview, n, (MgShape**)&shapes.front(), true) == n) {
        for (UInt32 i = 0; i < n; i++) {
            shapes[i]->context()->setLineWidth(w, true);
        }
        _motion->view->redraw(false);
    }
    else {
        _mgview->context()->setLineWidth(w, true);
    }
}

- (GiColor)lineColor {
    return [self currentContext]->getLineColor();
}

- (void)setLineColor:(GiColor)c {
    UInt32 n = mgGetCommandManager()->getSelection(_mgview, 0, NULL, true);
    std::vector<MgShape*> shapes(n, NULL);
    
    if (n > 0 && mgGetCommandManager()->getSelection(_mgview, n, (MgShape**)&shapes.front(), true) == n) {
        for (UInt32 i = 0; i < n; i++) {
            shapes[i]->context()->setLineColor(c);
        }
        _motion->view->redraw(false);
    }
    else {
        _mgview->context()->setLineColor(c);
    }
}

- (GiColor)fillColor {
    return [self currentContext]->getFillColor();
}

- (void)setFillColor:(GiColor)c {
    UInt32 n = mgGetCommandManager()->getSelection(_mgview, 0, NULL, true);
    std::vector<MgShape*> shapes(n, NULL);
    
    if (n > 0 && mgGetCommandManager()->getSelection(_mgview, n, (MgShape**)&shapes.front(), true) == n) {
        for (UInt32 i = 0; i < n; i++) {
            shapes[i]->context()->setFillColor(c);
        }
        _motion->view->redraw(false);
    }
    else {
        _mgview->context()->setFillColor(c);
    }
}

- (int)lineStyle {
    return [self currentContext]->getLineStyle();
}

- (void)setLineStyle:(int)style {
    UInt32 n = mgGetCommandManager()->getSelection(_mgview, 0, NULL, true);
    std::vector<MgShape*> shapes(n, NULL);
    
    if (n > 0 && mgGetCommandManager()->getSelection(_mgview, n, (MgShape**)&shapes.front(), true) == n) {
        for (UInt32 i = 0; i < n; i++) {
            shapes[i]->context()->setLineStyle((GiLineStyle)style);
        }
        _motion->view->redraw(false);
    }
    else {
        _mgview->context()->setLineStyle((GiLineStyle)style);
    }
}

- (BOOL)autoFillColor {
    return [self currentContext]->isAutoFillColor();
}

- (void)setAutoFillColor:(BOOL)value {
    UInt32 n = mgGetCommandManager()->getSelection(_mgview, 0, NULL, true);
    std::vector<MgShape*> shapes(n, NULL);
    
    if (n > 0 && mgGetCommandManager()->getSelection(_mgview, n, (MgShape**)&shapes.front(), true) == n) {
        for (UInt32 i = 0; i < n; i++) {
            shapes[i]->context()->setAutoFillColor(value);
        }
        _motion->view->redraw(false);
    }
    else {
        _mgview->context()->setAutoFillColor(value);
    }
}

- (BOOL)dynamicChangeEnded:(BOOL)apply
{
    return mgGetCommandManager()->dynamicChangeEnded(_mgview, apply);
}

- (BOOL)currentShapeFixedLength
{
    MgSelection *sel = mgGetCommandManager()->getSelection(_mgview);
    return sel && sel->isFixedLength(_mgview);
}

- (void)setCurrentShapeFixedLength:(BOOL)fixed
{
    MgSelection *sel = mgGetCommandManager()->getSelection(_mgview);
    if (sel && sel->setFixedLength(_mgview, !!fixed)) {}
}

- (CGPoint)getPointW {
    Point2d pt(_motion->pointM * _mgview->xform()->modelToWorld());
    return CGPointMake(pt.x, pt.y);
}

- (BOOL)dynDraw:(GiGraphics*)gs
{
    MgCommand* cmd = mgGetCommandManager()->getCommand();
    if (cmd && _mgview->getView()) {
        cmd->draw(_motion, gs);
    }
    return YES;
}

- (void)getDynamicShapes:(MgShapes*)shapes
{
    MgCommand* cmd = mgGetCommandManager()->getCommand();
    if (cmd && _mgview->getView()) {
        cmd->gatherShapes(_motion, shapes);
    }
}

- (BOOL)isDynamicChanged:(BOOL)reset
{
    BOOL ret = _mgview->_dynChanged;
    if (reset)
        _mgview->_dynChanged = NO;
    return ret;
}

- (BOOL)cancel
{
    _motion->pressDrag = false;
    _motion->dragging = false;
    _motion->pressDrag = false;
    _twoFingersHandled = NO;
    return _mgview->getView() && mgGetCommandManager()->cancel(_motion);
}

- (BOOL)undoMotion
{
    MgCommand* cmd = mgGetCommandManager()->getCommand();
    bool recall;
    return cmd && _mgview->getView() && cmd->undo(recall, _motion);
}

- (void)touchesBegan:(CGPoint)point view:(UIView*)view count:(int)count
{
    [GiCommandController hideContextActions];
    
    if (_touchCount <= count) {
        _touchCount = count;
        
        if ([self setView:view] && count == 1) {
            [self convertPoint:point];
            _motion->startPoint = _motion->point;
            _motion->startPointM = _motion->pointM;
            _motion->lastPoint = _motion->point;
            _motion->lastPointM = _motion->pointM;
            _motion->velocity = 0;
            _motion->pressDrag = false;
            _moved = NO;
            _clickFingers = 0;
            _undoFired = NO;
            _twoFingersHandled = NO;
        }
    }
}

- (BOOL)touchesMoved:(CGPoint)point view:(UIView*)view count:(int)count
{
    MgCommand* cmd = mgGetCommandManager()->getCommand();
    BOOL ret = NO;
    
    if (!_moved && cmd) {
        _moved = YES;
        ret = cmd->touchBegan(_motion);
    }
    if (cmd) {
        [self setView:view];
        
        if (!_motion->pressDrag && count > 1) {             // 变为双指滑动
            bool recall = false;
            if (!_undoFired) {                              // 双指滑动后可再触发Undo操作
                if (cmd->undo(recall, _motion) && !recall)  // 触发一次Undo操作
                    _undoFired = true;                      // 另一个手指不松开也不再触发Undo操作
            }
        }
        else {
            [self convertPoint:point];
            
            ret = cmd->touchMoved(_motion);
            _undoFired = false;                             // 允许再触发Undo操作
            _motion->dragging = true;
            _motion->lastPoint = _motion->point;
            _motion->lastPointM = _motion->pointM;
        }
    }
    
    return !!cmd;
}

- (BOOL)touchesEnded:(CGPoint)point view:(UIView*)view count:(int)count
{
    MgCommand* cmd = mgGetCommandManager()->getCommand();
    BOOL ret = NO;
    
    if (cmd) {
        [self setView:view];
        [self convertPoint:point];
        
        ret = cmd->touchEnded(_motion);
        _motion->pressDrag = false;
        _touchCount = 0;
        _motion->dragging = false;
        _motion->pressDrag = false;
    }
    
    return ret;
}

- (BOOL)oneFingerPan:(UIPanGestureRecognizer *)sender
{
    MgDynShapeLock locker;
    MgCommand* cmd = mgGetCommandManager()->getCommand();
    BOOL ret = NO;
    CGPoint point;
    
    if (cmd && locker.locked())
    {
        if (sender.state == UIGestureRecognizerStatePossible) {
            return _motion->pressDrag || [sender numberOfTouches] == 1;
        }
        if (sender.state == UIGestureRecognizerStateBegan) {
            if (_touchCount > [sender numberOfTouches]) {
                _touchCount = [sender numberOfTouches];
                point = [sender locationInView:sender.view];
                [self touchesBegan:point view:sender.view count:_touchCount];
            }
        }
        else if (sender.state == UIGestureRecognizerStateChanged) {
            CGPoint velocity = [sender velocityInView:sender.view];
            _motion->velocity = hypotf(velocity.x, velocity.y);
            
            ret = ([self getPointForPressDrag:sender :&point]
                   && [self touchesMoved:point view:sender.view
                                   count:sender.numberOfTouches]);
        }
        else if (sender.state == UIGestureRecognizerStateEnded) {
            if ([sender numberOfTouches] && [self getPointForPressDrag:sender :&point]) {
                [self convertPoint:point];
            }
            ret = cmd->touchEnded(_motion);
            _touchCount = 0;
            _motion->dragging = false;
            _motion->pressDrag = false;
        }
        else if (sender.state > UIGestureRecognizerStateEnded) {
            ret = cmd->cancel(_motion);
            _touchCount = 0;
            _motion->dragging = false;
            _motion->pressDrag = false;
        }
        ret = YES;
    }
    
    return ret;
}

- (BOOL)twoFingersPinch:(UIPinchGestureRecognizer *)sender
{
    MgDynShapeLock locker;
    MgCommand* cmd = mgGetCommandManager()->getCommand();
    BOOL ret = [self handleSelectionTwoFingers:sender];
    CGPoint point;
    
    if (!ret && _motion->pressDrag && cmd && locker.locked()) {
        if (sender.state == UIGestureRecognizerStateBegan) {
            if (_touchCount > [sender numberOfTouches]) {
                _touchCount = [sender numberOfTouches];
                point = [sender locationInView:sender.view];
                [self touchesBegan:point view:sender.view count:_touchCount];
            }
        }
        else if (sender.state == UIGestureRecognizerStateChanged) {
            _motion->velocity = 0;
            ret = ([self getPointForPressDrag:sender :&point]
                   && [self touchesMoved:point view:sender.view
                                   count:sender.numberOfTouches]);
        }
        else if (sender.state == UIGestureRecognizerStateEnded) {
            if ([sender numberOfTouches]
                && [self getPointForPressDrag:sender :&point]) {
                [self convertPoint:point];
            }
            ret = cmd->touchEnded(_motion);
            _touchCount = 0;
            _motion->dragging = false;
            _motion->pressDrag = false;
        }
        else if (sender.state > UIGestureRecognizerStateEnded) {
            ret = cmd->cancel(_motion);
            _touchCount = 0;
            _motion->dragging = false;
            _motion->pressDrag = false;
        }
        ret = YES;
    }
    
    return ret;
}

- (BOOL)handleSelectionTwoFingers:(UIGestureRecognizer *)sender
{
    if (sender.state <= UIGestureRecognizerStateBegan || _twoFingersHandled) {
        CGPoint pt1, pt2;
        
        if ([sender numberOfTouches] == 2) {
            pt1 = [sender locationOfTouch:0 inView:sender.view];
            pt2 = [sender locationOfTouch:1 inView:sender.view];
        }
        else if (sender.state == UIGestureRecognizerStateChanged) {
            return _twoFingersHandled;
        }
        
        MgSelection *sel = mgGetCommandManager()->getSelection(_mgview);
        Point2d pnt1 = Point2d(pt1.x, pt1.y) * _mgview->xform()->displayToModel();
        Point2d pnt2 = Point2d(pt2.x, pt2.y) * _mgview->xform()->displayToModel();
        
        if (sel && sel->handleTwoFingers(_motion, sender.state, pnt1, pnt2)) {
            _twoFingersHandled = (sender.state < UIGestureRecognizerStateEnded);
        }
    }
    
    return _twoFingersHandled;
}

- (BOOL)twoFingersPan:(UIPanGestureRecognizer *)sender
{
    MgDynShapeLock locker;
    return [self handleSelectionTwoFingers:sender];
}

- (BOOL)twoFingersRotate:(UIRotationGestureRecognizer *)sender
{
    MgDynShapeLock locker;
    return [self handleSelectionTwoFingers:sender];
}

- (BOOL)oneFingerTwoTaps:(UITapGestureRecognizer *)sender
{
    _clickFingers = 2;
    return mgGetCommandManager()->getCommand() != NULL;
}

- (BOOL)longPressGesture:(UIGestureRecognizer *)sender
{
    MgCommand* cmd = mgGetCommandManager()->getCommand();
    BOOL ret = NO;
    
    if (cmd) {
        if (sender.state < UIGestureRecognizerStateBegan) {
            ret = YES;
        }
        else {
            [self setView:sender.view];
            [self convertPoint:[sender locationInView:sender.view]];
            
            _motion->pressDrag = true;      // 设置长按标记
            if (sender.state == UIGestureRecognizerStateBegan) {
                _motion->startPoint = _motion->point;
                _motion->startPointM = _motion->pointM;
                _motion->lastPoint = _motion->point;
                _motion->lastPointM = _motion->pointM;
            }
            else if (sender.state >= UIGestureRecognizerStateEnded
                     && _motion->startPoint.distanceTo(_motion->point) < 10) {
                return YES;                 // 长按不动再松开时，忽略Ended消息
            }
            
            ret = cmd->longPress(_motion);
        }
    }
    
    return ret;
}

- (BOOL)oneFingerOneTap:(UITapGestureRecognizer *)sender
{
    _clickFingers = 1;
    return mgGetCommandManager()->getCommand() != NULL;
}

- (BOOL)delayTap:(CGPoint)point view:(UIView*)view
{
    MgCommand* cmd = mgGetCommandManager()->getCommand();
    BOOL ret = NO;
    
    if (cmd && _clickFingers > 0 && !_motion->pressDrag) {
        [self setView:view];
        [self convertPoint:point];
        _touchCount = 0;
        
        // 当放大镜显示时，在主视图中点击将不向随手画命令传递点击事件，而是在主视图中显示放大镜位置虚框
        if (strcmp(cmd->getName(), "select") != 0   // 选择和删除命令例外
            && strcmp(cmd->getName(), "erase") != 0
            && _mgview->isMagnifierVisible()
            && view == [_mgview->getMainView() ownerView]) {
            
            [_mgview->getView() redraw:true];
            ret = YES;
            if (strcmp(cmd->getName(), "splines") != 0 && 1 == _clickFingers) {
                cmd->click(_motion);                // 除了随手画命令外，将向命令传递点击事件
            }
        }
        else if (1 == _clickFingers) {
            ret = cmd->click(_motion);
        }
        else if (2 == _clickFingers) {
            ret = cmd->doubleClick(_motion);
        }
    }
    _clickFingers = 0;
    _motion->dragging = false;
    
    return ret;
}

@end
