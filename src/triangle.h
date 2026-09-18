#ifndef __TRIANGLE_H__
#define __TRIANGLE_H__
#include "plane.h"

class Triangle : public Plane{
public:
   double thirdX;
   Triangle(Vector c, Vector b, Vector a, Texture* t);
   double getIntersection(const Ray &ray) override;
   bool getLightIntersection(const Ray &ray, double* fill) override;
};

#endif
