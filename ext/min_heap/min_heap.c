#include <assert.h>
#include <ruby.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>

#define THRESHOLD 100

#define unlikely(x) __builtin_expect((x),0)

#define compare(heap, i, j) (heap->nodes[i].average < heap->nodes[j].average)

#define is_available(heap, node) (                                 \
  (heap->is_available == Qnil) ||                                  \
  (rb_funcall(heap->is_available, id_call, 1, node->obj) == Qtrue) \
)

#define MAX(a, b) (a < b ? b : a)

static ID id_call;

typedef struct node {
  VALUE obj;
  int index;
  int average;
  int samples;
  int weight;
} node_t;

typedef struct heap {
  int capacity;
  int size;
  int sample_size;
  VALUE is_available;
  int cur_index;
  node_t *nodes;
} heap_t;

static void _fix_down(heap_t *, int, int);
static node_t *_get(heap_t *, int);

static void *
zalloc(size_t size)
{
  void *p;

  p = malloc(size);

  if (p != NULL) {
    memset(p, 0, size);
  }

  return p;
}

static inline void
swap(heap_t *heap, int i, int j)
{
  node_t tmp = heap->nodes[i];
  heap->nodes[i] = heap->nodes[j];
  heap->nodes[j] = tmp;
  heap->nodes[i].index = i;
  heap->nodes[j].index = j;
}

void
heap_mark(heap_t *heap)
{
  if (heap == NULL) return;

  rb_gc_mark(heap->is_available);

  if (heap->nodes != NULL) {
    node_t *node = heap->nodes;
    for (int i = 0; i < heap->size; i++, node++) {
      if (node != NULL) rb_gc_mark(node->obj);
    }
  }
}

void
heap_free(heap_t *heap)
{
  if (heap == NULL) return;

  if (heap->nodes != NULL) {
    free(heap->nodes);
  }

  free(heap);
}

int
heap_setup(heap_t *heap, int size, int samples)
{
  assert(size > 0);

  int capacity = size + 1;

  heap->capacity = capacity;
  heap->size = 0;
  heap->cur_index = 0;
  heap->is_available = Qnil;
  heap->sample_size = samples;

  node_t *node = zalloc(sizeof(node_t) * capacity);
  if (unlikely(node == NULL)) {
    heap_free(heap);
    return -1;
  }

  heap->nodes = node;

  return 0;
}

int
heap_insert(heap_t *heap, VALUE obj)
{
  assert(heap != NULL);

  // Tried inserting more items than the heap has capacity for
  if (heap->size + 1 > heap->capacity) {
    return 1;
  }

  heap->size++;
  node_t *node = &heap->nodes[heap->size];
  node->index = heap->size;
  node->samples = 0;
  node->weight = 0;
  node->average = 0;
  node->obj = obj;

  return 0;
}

VALUE
heap_checkout(VALUE self)
{
  heap_t *heap;
  Data_Get_Struct(self, heap_t, heap);

  if (heap->cur_index > 0)
    rb_raise(rb_eRuntimeError, "You must check an item in before checking a new one out");

  // Use this when we need to check node liveness
  node_t *node = _get(heap, 1);
  VALUE obj = is_available(heap, node) ? node->obj : Qnil;

  if (obj != Qnil)
    heap->cur_index = node->index;

  return obj;
}

/* This will be useful when we can check the liveness of nodes */
static node_t *
_get(heap_t *heap, int i)
{
  assert(heap != NULL);
  assert(i > 0);
  assert(i <= heap->size);

  node_t *node = &heap->nodes[i];

  if (is_available(heap, node) || heap->size < i*2) {

  } else if (heap->size == i*2) {
    node = _get(heap, i*2);

  } else {
    node_t *left = _get(heap, i*2);
    node_t *right = _get(heap, i*2+1);
    node = (left->average <= right->average && is_available(heap, left)) ? left : right;
  }

  return node;
}

VALUE
heap_checkin(VALUE self)
{
  heap_t *heap;
  Data_Get_Struct(self, heap_t, heap);

  if (heap->cur_index == 0) return;

  node_t *node = &heap->nodes[heap->cur_index];
  heap->cur_index = 0;
  _fix_down(heap, node->index, heap->size);

  return self;
}

VALUE
heap_add_sample(VALUE self, VALUE sample)
{
  heap_t *heap;
  Data_Get_Struct(self, heap_t, heap);

  // assume we can't check out more than one item at a time
  if (heap->cur_index == 0)
    rb_raise(rb_eRuntimeError, "Must checkout a node before adding samples");

  node_t *node = &heap->nodes[heap->cur_index];
  node->samples++;

  int weight = node->weight;
  if (node->samples <= THRESHOLD)
    weight = MAX(THRESHOLD / node->samples, node->weight);

  node->average = (100 - weight) * node->average / 100 + weight * sample / 100;

  return self;
}

static void
_fix_down(heap_t *heap, int i, int j)
{
  assert(heap != NULL);

  if (j < i*2) return;

  int m = (j == i*2 || compare(heap, 2*i, 2*i+1)) ? (2*i) : (2*i+1);
  if (compare(heap, m, i)) {
    swap(heap, i, m);
    _fix_down(heap, m, j);
  }
}

static VALUE
heap_initialize(VALUE self, VALUE weight, VALUE items)
{
  assert(TYPE(weight) == T_FIXNUM);
  assert(TYPE(items) == T_ARRAY);

  if (FIX2INT(weight) < 0 || FIX2INT(weight) > 100)
    rb_raise(rb_eRuntimeError, "Weight must be between 0 and 100");

  heap_t *heap;
  Data_Get_Struct(self, heap_t, heap);

  long int size = RARRAY_LEN(items);

  if (heap_setup(heap, size, FIX2INT(weight)) < 0)
    rb_raise(rb_eRuntimeError, "Unable to initialize heap");

  if (rb_block_given_p())
    heap->is_available = rb_block_proc();

  VALUE *item = RARRAY_PTR(items);
  for (long i = 0; i < size; i++) {
    heap_insert(heap, *item);
    item++;
  }

  return Qnil;
}

static VALUE
heap_alloc(VALUE klass)
{
  return Data_Wrap_Struct(klass, heap_mark, heap_free, zalloc(sizeof(heap_t)));
}

static VALUE
heap_current_state(VALUE self)
{
  heap_t *heap;
  Data_Get_Struct(self, heap_t, heap);

  VALUE ary = rb_ary_new2(heap->size);
  VALUE sub_ary;
  node_t *node = &heap->nodes[1];
  for (int i = 1; i <= heap->size; i++, node++) {
    sub_ary = rb_ary_new3(3, node->obj, INT2FIX(node->average), INT2FIX(node->index));
    rb_ary_push(ary, sub_ary);
  }

  return ary;
}

void
Init_min_heap(void)
{
  id_call = rb_intern("call");

  VALUE heap = rb_define_class("MinHeap", rb_cObject);

  rb_define_alloc_func(heap, heap_alloc);
  rb_define_method(heap, "initialize", heap_initialize, 2);
  rb_define_method(heap, "checkout", heap_checkout, 0);
  rb_define_method(heap, "add_sample", heap_add_sample, 1);
  rb_define_method(heap, "checkin", heap_checkin, 0);
  rb_define_method(heap, "current_state", heap_current_state, 0);
}
