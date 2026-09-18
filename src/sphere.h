#ifndef __SPHERE_H__
#define __SPHERE_H__
#include "shape.h"

class Sphere : public Shape{
public:
  double radius;
  Sphere(const Vector &c, Texture* t, double ya, double pi, double ro, double radius);
  double getIntersection(const Ray &ray) override;
  void move();
  bool getLightIntersection(const Ray &ray, double* fill) override;
  void getColor(unsigned char* toFill, double* am, double* op, double* ref, Autonoma* r, const Ray &ray, unsigned int depth) override;
  Vector getNormal(const Vector &point) override;
  unsigned char reversible();
  void setAngles(double a, double b, double c);
  void setYaw(double a);
  void setPitch(double b);
  void setRoll(double c);
};
#endif
