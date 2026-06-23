import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/sketch_element.dart';
import 'element_bounds.dart';

/// Moves [el] by ([dx], [dy]) in world space, mutating it in place.
void translateElement(SketchElement el, double dx, double dy) {
  SkPoint shift(SkPoint p) => SkPoint(p.x + dx, p.y + dy);
  switch (el) {
    case FreehandElement():
      el.points = el.points.map(shift).toList();
    case ShapeElement():
      el.start = shift(el.start);
      el.end = shift(el.end);
      if (el.tailTip != null) el.tailTip = shift(el.tailTip!);
    case TextElement():
      el.position = shift(el.position);
    case ImageElement():
      el.position = shift(el.position);
    case GroupElement():
      for (final sub in el.elements) {
        translateElement(sub, dx, dy);
      }
    case RawElement():
      break;
  }
}

/// Rotates [el] by [delta] radians about [pivot] (world space): orbits the
/// element's centre around [pivot] and adds [delta] to its own rotation.
void rotateElementAbout(SketchElement el, Offset pivot, double delta) {
  final c = elementBounds(el).center;
  final cos = math.cos(delta), sin = math.sin(delta);
  final dx = c.dx - pivot.dx, dy = c.dy - pivot.dy;
  final nc = Offset(
    pivot.dx + dx * cos - dy * sin,
    pivot.dy + dx * sin + dy * cos,
  );
  translateElement(el, nc.dx - c.dx, nc.dy - c.dy);
  el.rotation += delta;
}

/// Remaps [el]'s geometry from the [from] bounding box to the [to] box,
/// mutating it in place. Used by the resize handles.
void resizeElement(SketchElement el, Rect from, Rect to) {
  if (from.width == 0 || from.height == 0) return;
  final sx = to.width / from.width;
  final sy = to.height / from.height;

  SkPoint map(SkPoint p) =>
      SkPoint(to.left + (p.x - from.left) * sx, to.top + (p.y - from.top) * sy);

  switch (el) {
    case FreehandElement():
      el.points = el.points.map(map).toList();
    case ShapeElement():
      el.start = map(el.start);
      el.end = map(el.end);
      if (el.tailTip != null) el.tailTip = map(el.tailTip!);
    case TextElement():
      el.position = map(el.position);
      el.fontSize = (el.fontSize * sy).clamp(4.0, 800.0);
    case ImageElement():
      el.position = map(el.position);
      el.imageWidth = (el.imageWidth * sx).abs();
      el.imageHeight = (el.imageHeight * sy).abs();
    case GroupElement():
      for (final sub in el.elements) {
        resizeElement(sub, from, to);
      }
    case RawElement():
      break;
  }
}
