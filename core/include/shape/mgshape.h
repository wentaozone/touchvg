//! \file mgshape.h
//! \brief 定义矢量图形基类 MgBaseShape 和 MgShape
// Copyright (c) 2004-2012, Zhang Yungui
// License: LGPL, https://github.com/rhcad/touchvg

#ifndef __GEOMETRY_MGSHAPE_H_
#define __GEOMETRY_MGSHAPE_H_

#include <mgbox.h>

class Matrix2d;
class GiGraphics;
class GiContext;
class MgBaseShape;
struct MgShape;
struct MgShapes;
struct MgStorage;

//! 图形对象基类
/*! \ingroup GEOM_SHAPE
    \interface MgObject
*/
struct MgObject
{
    //! 复制出一个新对象
    virtual MgObject* clone() const = 0;

    //! 复制对象数据
    virtual void copy(const MgObject& src) = 0;

    //! 销毁对象
    virtual void release() = 0;

    //! 比较与另一同类对象是否相同
    virtual bool equals(const MgObject& src) const = 0;

    //! 返回对象类型
    virtual UInt32 getType() const = 0;

    //! 返回是否能转化为指定类型的对象，即本类为指定类或其派生类
    virtual bool isKindOf(UInt32 type) const = 0;
};

//! 矢量图形接口
/*! \ingroup GEOM_SHAPE
    \interface MgShape
*/
struct MgShape : public MgObject
{
    static UInt32 Type() { return 2; }

    virtual GiContext* context() = 0;
    virtual const GiContext* contextc() const = 0;
    virtual MgBaseShape* shape() = 0;
    virtual const MgBaseShape* shapec() const = 0;
    virtual bool draw(GiGraphics& gs, const GiContext *ctx = NULL) const = 0;
    virtual bool save(MgStorage* s) const = 0;
    virtual bool load(MgStorage* s) = 0;

    virtual UInt32 getID() const = 0;
    virtual MgShapes* getParent() const = 0;
    virtual void setParent(MgShapes* p, UInt32 nID) = 0;
    virtual UInt32 getTag() const = 0;
    virtual void setTag(UInt32 tag) = 0;
};

//! 图形特征标志位
typedef enum {
    kMgSquare,          //!< 方形
    kMgClosed,          //!< 闭合
    kMgFixedLength,     //!< 边长固定
    kMgShapeLocked,     //!< 锁定形状
    kMgRotateDisnable,  //!< 不能旋转
} MgShapeBit;

//! 矢量图形基类
/*! \ingroup GEOM_SHAPE
*/
class MgBaseShape : public MgObject
{
protected:
    MgBaseShape();
    virtual ~MgBaseShape();

public:
    //! 返回本对象的类型
    static UInt32 Type() { return 3; }

public:
    //! 返回图形模型坐标范围
    virtual Box2d getExtent() const = 0;

    //! 参数改变后重新计算坐标
    virtual void update() = 0;

    //! 矩阵变换
    virtual void transform(const Matrix2d& mat) = 0;

    //! 清除图形数据
    virtual void clear() = 0;

    //! 返回顶点个数
    virtual UInt32 getPointCount() const = 0;

    //! 返回指定序号的顶点
    virtual Point2d getPoint(UInt32 index) const = 0;

    //! 设置指定序号的顶点坐标，需再调用 update()
    virtual void setPoint(UInt32 index, const Point2d& pt) = 0;

    //! 返回是否闭合
    virtual bool isClosed() const = 0;

    //! 选中点击测试
    /*!
        \param[in] pt 外部点的模型坐标，将判断此点能否点中图形
        \param[in] tol 距离公差，正数，超出则不计算最近点
        \param[out] nearpt 图形上的最近点
        \param[out] segment 最近点所在部分的序号，其含义由派生图形类决定
        \return 给定的外部点到最近点的距离，失败时为极大数
    */
    virtual float hitTest(const Point2d& pt, float tol, 
       Point2d& nearpt, Int32& segment) const = 0;
    
    //! 框选检查
    virtual bool hitTestBox(const Box2d& rect) const = 0;

    //! 显示图形
    virtual bool draw(GiGraphics& gs, const GiContext& ctx) const = 0;
    
    //! 保存图形
    virtual bool save(MgStorage* s) const = 0;
    
    //! 恢复图形
    virtual bool load(MgStorage* s) = 0;
    
    //! 返回控制点个数
    virtual UInt32 getHandleCount() const = 0;
    
    //! 返回指定序号的控制点坐标
    virtual Point2d getHandlePoint(UInt32 index) const = 0;
    
    //! 设置指定序号的控制点坐标，指定的容差用于比较重合点
    virtual bool setHandlePoint(UInt32 index, const Point2d& pt, float tol) = 0;
    
    //! 移动图形, segment 由 hitTest() 得到
    virtual bool offset(const Vector2d& vec, Int32 segment) = 0;
    
    //! 得到图形特征标志位
    bool getFlag(MgShapeBit bit) const;
    
    //! 设置图形特征标志位
    virtual void setFlag(MgShapeBit bit, bool on);
    
protected:
    Box2d   _extent;
    UInt32  _flags;

protected:
    bool _isClosed() const { return getFlag(kMgClosed); }
    void _copy(const MgBaseShape& src);
    bool _equals(const MgBaseShape& src) const;
    bool _isKindOf(UInt32 type) const;
    Box2d _getExtent() const { return _extent; }
    void _update();
    void _transform(const Matrix2d& mat);
    void _clear();
    bool _draw(GiGraphics& gs, const GiContext& ctx) const;
    bool _hitTestBox(const Box2d& rect) const;
    UInt32 _getHandleCount() const;
    Point2d _getHandlePoint(UInt32 index) const;
    bool _setHandlePoint(UInt32 index, const Point2d& pt, float tol);
    bool _offset(const Vector2d& vec, Int32 segment);
    bool _rotateHandlePoint(UInt32 index, const Point2d& pt);
    bool _save(MgStorage* s) const;
    bool _load(MgStorage* s);
};

#if !defined(_MSC_VER) || _MSC_VER <= 1200
#define MG_DECLARE_DYNAMIC(Cls, Base)                           \
    typedef Base __super;
#else
#define MG_DECLARE_DYNAMIC(Cls, Base)
#endif

#define MG_INHERIT_CREATE(Cls, Base, TypeNum)                   \
    MG_DECLARE_DYNAMIC(Cls, Base)                               \
public:                                                         \
    Cls();                                                      \
    virtual ~Cls();                                             \
    static Cls* create();                                       \
    static UInt32 Type() { return TypeNum; }                    \
protected:                                                      \
    bool _isKindOf(UInt32 type) const;                          \
protected:                                                      \
    bool _draw(GiGraphics& gs, const GiContext& ctx) const;     \
private:                                                        \
    virtual MgObject* clone() const;                            \
    virtual void copy(const MgObject& src);                     \
    virtual void release();                                     \
    virtual bool equals(const MgObject& src) const;             \
    virtual UInt32 getType() const { return Type(); }           \
    virtual bool isKindOf(UInt32 type) const { return _isKindOf(type); } \
    virtual Box2d getExtent() const;                            \
    virtual void update();                                      \
    virtual void transform(const Matrix2d& mat);                \
    virtual void clear();                                       \
    virtual UInt32 getPointCount() const;                       \
    virtual Point2d getPoint(UInt32 index) const;               \
    virtual void setPoint(UInt32 index, const Point2d& pt);     \
    virtual bool isClosed() const;                              \
    virtual float hitTest(const Point2d& pt, float tol,         \
       Point2d& nearpt, Int32& segment) const;                  \
    virtual bool hitTestBox(const Box2d& rect) const;           \
    virtual bool draw(GiGraphics& gs, const GiContext& ctx) const;  \
    virtual bool save(MgStorage* s) const;                      \
    virtual bool load(MgStorage* s);                            \
    virtual UInt32 getHandleCount() const;                      \
    virtual Point2d getHandlePoint(UInt32 index) const;         \
    virtual bool setHandlePoint(UInt32 index, const Point2d& pt, float tol);   \
    virtual bool offset(const Vector2d& vec, Int32 segment);

#define MG_DECLARE_CREATE(Cls, Base, TypeNum)                   \
    MG_INHERIT_CREATE(Cls, Base, TypeNum)                       \
protected:                                                      \
    void _copy(const Cls& src);                                 \
    bool _equals(const Cls& src) const;                         \
protected:                                                      \
    void _update();                                             \
    void _transform(const Matrix2d& mat);                       \
    void _clear();                                              \
    float _hitTest(const Point2d& pt, float tol,                \
       Point2d& nearpt, Int32& segment) const;                  \
    UInt32 _getPointCount() const;                              \
    Point2d _getPoint(UInt32 index) const;                      \
    void _setPoint(UInt32 index, const Point2d& pt);            \

#endif // __GEOMETRY_MGSHAPE_H_
