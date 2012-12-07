#include <assert.h>
#include <ruby.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>

#define THRESHOLD 100

#define is_available(heap, node) (                                 \
  (heap->is_available == Qnil) ||                                  \
  (rb_funcall(heap->is_available, id_call, 1, node->obj) == Qtrue) \
)

#define MAX(a, b) ((a) < (b) ? (b) : (a))

static ID id_call;
static ID id_inspect;

typedef struct node {
  VALUE obj;
  int index;
  double load;
  long int samples;
  int weight;
} tc_node_t;

typedef struct heap {
  int size;
  VALUE is_available;
  int cur_index;
  tc_node_t *nodes;
} tc_heap_t;

static void _fix_down(tc_heap_t *, int, int);
static tc_node_t *_get(tc_heap_t *, int);

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

static int
compare(tc_heap_t *heap, tc_node_t *i, tc_node_t *j)
{
  int i_avail = is_available(heap, i);
  int j_avail = is_available(heap, j);

  if (i_avail && !j_avail)
    return 1;

  if (!i_avail && j_avail)
    return 0;

  return i->load < j->load;
}

static inline void
swap(tc_heap_t *heap, int i, int j)
{
  tc_node_t tmp = heap->nodes[i];
  heap->nodes[i] = heap->nodes[j];
  heap->nodes[j] = tmp;
  heap->nodes[i].index = i;
  heap->nodes[j].index = j;
}

static void
heap_mark(tc_heap_t *heap)
{
  if (heap == NULL)
    return;

  rb_gc_mark(heap->is_available);

  if (heap->nodes != NULL) {
    tc_node_t *node = &heap->nodes[1];
    for (int i = 1; i <= heap->size; i++, node++)
      rb_gc_mark(node->obj);
  }
}

static void
heap_free(tc_heap_t *heap)
{
  if (heap == NULL)
    return;

  if (heap->nodes != NULL)
    free(heap->nodes);

  free(heap);
}

static VALUE
heap_checkout(VALUE self)
{
  tc_heap_t *heap;
  Data_Get_Struct(self, tc_heap_t, heap);

  if (heap->cur_index > 0)
    rb_raise(rb_eRuntimeError, "You must check an item in before checking a new one out");

  // Use this when we need to check node liveness
  tc_node_t *node = _get(heap, 1);
  VALUE obj = is_available(heap, node) ? node->obj : Qnil;

  if (obj != Qnil)
    heap->cur_index = node->index;

  return obj;
}

/* This will be useful when we can check the liveness of nodes */
static tc_node_t *
_get(tc_heap_t *heap, int i)
{
  assert(heap != NULL);
  assert(i > 0);
  assert(i <= heap->size);

  tc_node_t *node = &heap->nodes[i];

  if (is_available(heap, node) || heap->size < i*2) {

  } else if (heap->size == i*2) {
    node = _get(heap, i*2);

  } else {
    tc_node_t *left = _get(heap, i*2);
    tc_node_t *right = _get(heap, i*2+1);
    node = compare(heap, left, right) ? left : right;
  }

  return node;
}

static VALUE
heap_checkin(VALUE self)
{
  tc_heap_t *heap;
  Data_Get_Struct(self, tc_heap_t, heap);

  if (heap->cur_index == 0)
    return self;

  tc_node_t *node = &heap->nodes[heap->cur_index];
  heap->cur_index = 0;
  _fix_down(heap, node->index, heap->size);

  return self;
}

static VALUE
heap_add_sample(VALUE self, VALUE sample)
{
  tc_heap_t *heap;
  Data_Get_Struct(self, tc_heap_t, heap);

  // assume we can't check out more than one item at a time
  if (heap->cur_index == 0)
    return self;

  tc_node_t *node = &heap->nodes[heap->cur_index];
  node->samples++;

  int weight = node->weight;
  if (node->samples <= THRESHOLD)
    weight = MAX(THRESHOLD / node->samples, weight);

  node->load = (100.0 - weight) * node->load / 100.0 + weight * sample / 100.0;

  return self;
}

static void
_fix_down(tc_heap_t *heap, int i, int j)
{
  assert(heap != NULL);

  if (j < i*2) return;

  int m = (j == i*2 || compare(heap, &heap->nodes[2*i], &heap->nodes[2*i+1])) ? (2*i) : (2*i+1);
  if (compare(heap, &heap->nodes[m], &heap->nodes[i])) {
    swap(heap, i, m);
    _fix_down(heap, m, j);
  }
}

static VALUE
heap_initialize(VALUE self, VALUE w, VALUE items)
{
  assert(TYPE(w) == T_FIXNUM);
  assert(TYPE(items) == T_ARRAY);

  int weight = FIX2INT(w);
  if (weight < 0 || weight > 100)
    rb_raise(rb_eRuntimeError, "Weight must be between 0 and 100");

  tc_heap_t *heap;
  Data_Get_Struct(self, tc_heap_t, heap);

  long int size = RARRAY_LEN(items);
  VALUE *item = RARRAY_PTR(items);

  heap->size = size;
  heap->cur_index = 0;
  heap->is_available = Qnil;

  if (rb_block_given_p())
    heap->is_available = rb_block_proc();

  tc_node_t *node = zalloc(sizeof(tc_node_t) * (heap->size + 1));
  if (node == NULL)
    rb_raise(rb_eRuntimeError, "Unable to initialize heap.");

  heap->nodes = node;

  for (long int i = 0; i < size; i++) {
    node++; // index 0 is a placeholder

    node->index = i + 1;
    node->samples = 0;
    node->weight = weight;
    node->load = 0;
    node->obj = item[i];
  }

  return self;
}

static VALUE
heap_alloc(VALUE klass)
{
  return Data_Wrap_Struct(klass, heap_mark, heap_free, zalloc(sizeof(tc_heap_t)));
}

static VALUE
heap_current_state(VALUE self)
{
  tc_heap_t *heap;
  Data_Get_Struct(self, tc_heap_t, heap);

  VALUE ary = rb_ary_new2(heap->size);
  VALUE sub_ary;
  tc_node_t *node = &heap->nodes[1];
  for (int i = 1; i <= heap->size; i++, node++) {
    sub_ary = rb_ary_new3(4,
        node->obj,
        ULONG2NUM(node->samples),
        rb_float_new(node->load),
        INT2FIX(node->index));
    rb_ary_push(ary, sub_ary);
  }

  return ary;
}

static VALUE
heap_inspect(VALUE self)
{
  VALUE current_state = heap_current_state(self);
  return rb_funcall(current_state, id_inspect, 0);
}

void
Init_min_heap(void)
{
  id_call = rb_intern("call");
  id_inspect = rb_intern("inspect");

  VALUE module = rb_const_get(rb_cObject, rb_intern("ThriftHelpers"));
  VALUE heap = rb_define_class_under(module, "MinHeap", rb_cObject);

  rb_define_alloc_func(heap, heap_alloc);
  rb_define_method(heap, "initialize", heap_initialize, 2);
  rb_define_method(heap, "checkout", heap_checkout, 0);
  rb_define_method(heap, "add_sample", heap_add_sample, 1);
  rb_define_method(heap, "checkin", heap_checkin, 0);
  rb_define_method(heap, "current_state", heap_current_state, 0);
  rb_define_method(heap, "inspect", heap_inspect, 0);
}
