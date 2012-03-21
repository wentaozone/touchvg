//! \file mgshapes.h
//! \brief 定义图形列表类 MgShapesT
// Copyright (c) 2004-2012, Zhang Yungui
// License: LGPL, https://github.com/rhcad/graph2d

#ifndef __GEOMETRY_MGSHAPES_TEMPL_H_
#define __GEOMETRY_MGSHAPES_TEMPL_H_

#include <mgshapes.h>

//! 图形列表类
/*! \ingroup _GEOM_SHAPE_
    \param Container 包含(MgShape*)的容器类型
*/
template <typename Container /*=std::vector<MgShape*>*/ >
class MgShapesT : public MgShapes
{
    typedef MgShapesT<Container> ThisClass;
public:
    MgShapesT()
    {
    }

    ~MgShapesT()
    {
        clear();
    }

    static UInt32 Type() { return 8; }
    UInt32 getType() const { return Type(); }

    bool isKindOf(UInt32 type) const
    {
        return type == Type() || type == MgShapes::Type();
    }

    void release()
    {
        delete this;
    }

    MgObject* clone() const
    {
        ThisClass *p = new ThisClass;
        return p;
    }

    void copy(const MgObject& src)
    {
        if (src.isKindOf(Type())) {
            const ThisClass& _src = (const ThisClass&)src;
            if (&_src != this) {
            }
        }
    }
    
    bool equals(const MgObject& src) const
    {
        bool ret = false;

        if (src.isKindOf(Type())) {
            const ThisClass& _src = (const ThisClass&)src;
            ret = (_shapes == _src._shapes);
        }

        return ret;
    }

    void clear()
    {
        Container::iterator it = _shapes.begin();
        for (; it != _shapes.end(); ++it)
            (*it)->release();
        _shapes.clear();
    }

    MgShape* addShape(const MgShape& src)
    {
        MgShape* p = (MgShape*)src.clone();
        if (p)
        {
            p->setParent(this, getNewID());
            _shapes.push_back(p);
        }
        return p;
    }

    UInt32 getShapeCount() const
    {
        return _shapes.size();
    }

    MgShape* getFirstShape(void*& it) const
    {
        it = (void*)0;
        return _shapes.empty() ? NULL : _shapes[0];
    }
    
    MgShape* getNextShape(void*& it) const
    {
        UInt32 index = 1 + (UInt32)it;
        if (index < _shapes.size()) {
            it = (void*)index;
            return _shapes[index];
        }
        return NULL;
    }

    MgShape* findShape(UInt32 id) const
    {
        Container::const_iterator it = _shapes.begin();
        for (; it != _shapes.end(); ++it)
        {
            if ((*it)->getID() == id)
                return *it;
        }
        return NULL;
    }

    Box2d getExtent() const
    {
        Box2d extent;
        Container::const_iterator it = _shapes.begin();

        for (; it != _shapes.end(); ++it)
        {
            extent.unionWith((*it)->shape()->getExtent());
        }

        return extent;
    }

    MgShape* hitTest(const Box2d& limits, Point2d& ptNear, Int32& segment) const
    {
        MgShape* retshape = NULL;
        Container::const_iterator it = _shapes.begin();
        double distMin = limits.width();

        for (; it != _shapes.end(); ++it)
        {
            const MgBaseShape* shape = (*it)->shape();

            if (shape->getExtent().isIntersect(limits))
            {
                Point2d tmpNear;
                Int32   tmpSegment;
                double  dist = shape->hitTest(limits.center(), 
                    limits.width() / 2, tmpNear, tmpSegment);

                if (distMin > dist) {
                    distMin = dist;
                    segment = tmpSegment;
                    ptNear = tmpNear;
                    retshape = *it;
                }
            }
        }

        return retshape;
    }

    void draw(GiGraphics& gs, const GiContext *ctx = NULL) const
    {
        Box2d clip(gs.getClipModel());
        Container::const_iterator it = _shapes.begin();

        for (; it != _shapes.end(); ++it)
        {
            if ((*it)->shape()->getExtent().isIntersect(clip))
                (*it)->draw(gs, ctx);
        }
    }

private:
    UInt32 getNewID()
    {
        UInt32 id = 1;

        if (!_shapes.empty())
            id = _shapes.back()->getID() + 1;
        while (findShape(id))
            id++;

        return id;
    }

protected:
    Container   _shapes;
};

#endif // __GEOMETRY_MGSHAPES_TEMPL_H_
