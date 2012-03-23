// mgcmddraw.h: 定义绘图命令基类
// Copyright (c) 2004-2012, Zhang Yungui
// License: LGPL, https://github.com/rhcad/graph2d

#ifndef __GEOMETRY_MGCOMMAND_DRAW_H_
#define __GEOMETRY_MGCOMMAND_DRAW_H_

#include <mgcmd.h>

class MgCommandDraw : public MgCommand
{
public:
    MgCommandDraw();
    virtual ~MgCommandDraw();
    
protected:
    bool _initialize(MgShape* (*creator)(), const MgMotion* sender);
    bool _touchBegan(const MgMotion* sender);
    bool _touchMoved(const MgMotion* sender);
    bool _touchEnded(const MgMotion* sender);
    bool _addshape(const MgMotion* sender);

    virtual bool cancel(const MgMotion* sender);
    virtual bool undo(const MgMotion* sender);
    virtual bool draw(const MgMotion* sender, GiGraphics* gs);
    virtual bool click(const MgMotion* sender);
    virtual bool doubleClick(const MgMotion* sender);
    virtual bool longPress(const MgMotion* sender);

protected:
    MgShape*    m_shape;
    UInt32      m_step;
};

class MgCmdBaseLines : public MgCommandDraw
{
public:
    MgCmdBaseLines();
    virtual ~MgCmdBaseLines();

protected:
    virtual bool draw(const MgMotion* sender, GiGraphics* gs);
    virtual bool touchBegan(const MgMotion* sender);
    virtual bool touchMoved(const MgMotion* sender);
    virtual bool touchEnded(const MgMotion* sender);

protected:
    virtual bool canAddPoint(const MgMotion* sender);
    virtual bool canAddShape(const MgMotion* sender);
};

#endif // __GEOMETRY_MGCOMMAND_DRAW_H_
