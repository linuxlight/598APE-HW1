#ifndef __PLANE_H__
#define __PLANE_H__

#include "shape.h"

class Plane : public Shape{
public:
  Vector vect, right, up;
  double d;
  Plane(const Vector &c, Texture* t, double ya, double pi, double ro, double tx, double ty);
  virtual double getIntersection(const Ray &ray) override;
  virtual bool getLightIntersection(const Ray &ray, double* toFill) override;
  void move();
  virtual void getColor(unsigned char* toFill, double* am, double* op, double* ref, Autonoma* r, const Ray &ray, unsigned int depth) override;
  Vector getNormal(const Vector &point);
  unsigned char reversible();
  void setAngles(double yaw, double pitch, double roll);
  void setYaw(double d);
  void setPitch(double d);
  void setRoll(double d);
};

#endif
