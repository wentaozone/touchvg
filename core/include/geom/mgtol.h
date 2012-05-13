//! \file mgtol.h
//! \brief 定义容差类 Tol
// Copyright (c) 2004-2012, Zhang Yungui
// License: LGPL, https://github.com/rhcad/touchvg

#ifndef __GEOMETRY_MGTOL_H_
#define __GEOMETRY_MGTOL_H_

#include "mgdef.h"

//! 容差类
/*!
    \ingroup GEOM_CLASS
    容差类含有长度容差和矢量容差。\n
    长度容差表示长度小于该值就认为是零长度，或两点距离小于该值就认为重合。\n
    矢量容差表示两个弧度角度小于该值就认为是相等，由于矢量容差一般很小，
    故对于矢量容差a，有a≈sin(a)≈tan(a)，cos(a)≈1。
*/
class Tol
{
public:
    //! 全局缺省容差
    /*! 该容差是数学几何库中很多函数的默认容差，可以修改该对象的容差值
    */
    static Tol& gTol()
    {
        static Tol tol;
        return tol;
    }
    
    //! 最小容差
    /*! 该容差的长度容差值和矢量容差值都为1e-10f
    */
    static const Tol& minTol()
    {
        static const Tol tol(0, 0);
        return tol;
    }
    
    //! 构造默认容差
    /*! 默认构造函数构造出的长度容差值为1e-7f，矢量容差值为1e-4f
    */
    Tol() : mTolPoint(1e-7f), mTolVector(1e-4f)
    {
    }
    
    //! 给定容差构造
    /*! 如果给定容差值小于1e-10f，将取最小容差值1e-10f
        \param tolPoint 长度容差值，正数
        \param tolVector 矢量容差值，正数，一般取小于0.1的数
    */
    Tol(float tolPoint, float tolVector)
    {
        setEqualPoint(tolPoint);
        setEqualVector(tolVector);
    }
    
    //! 返回长度容差
    float equalPoint() const
    {
        return mTolPoint;
    }
    
    //! 返回矢量容差
    float equalVector() const
    {
        return mTolVector;
    }
    
    //! 设置长度容差
    /*! 如果给定容差值小于1e-10f，将取最小容差值1e-10f
        \param tol 长度容差值，正数
    */
    void setEqualPoint(float tol)
    {
        if (tol < 1e-10f)
            tol = 1e-10f;
        mTolPoint = tol;
    }
    
    //! 设置矢量容差
    /*! 如果给定容差值小于1e-10f，将取最小容差值1e-10f
        \param tol 矢量容差值，正数，一般取小于0.1的数
    */
    void setEqualVector(float tol)
    {
        if (tol < 1e-10f)
            tol = 1e-10f;
        mTolVector = tol;
    }
    
private:
    float  mTolPoint;      //!< 长度容差
    float  mTolVector;     //!< 矢量容差
};

#endif // __GEOMETRY_MGTOL_H_
