#include <stdio.h>
#include <caml/bigarray.h>
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/custom.h>


CAMLprim value dot_c(value x_value, value y_value, value size_value)
{
  CAMLparam3(x_value, y_value, size_value);
  CAMLlocal1(ml_tot);
  double *x = Data_bigarray_val(x_value);
  double *y = Data_bigarray_val(y_value);
  int size = Int_val(size_value);
  double tot = 0;
  int i;
  for(i=0; i < size; i++) {
    tot += x[i] * y[i];
  }
  ml_tot = caml_copy_double(tot);
  CAMLreturn(ml_tot);
}


CAMLprim value triple_dot_c(value x_value, value y_value, value z_value, value size_value)
{
  CAMLparam4(x_value, y_value, z_value, size_value);
  CAMLlocal1(ml_tot);
  double *x = Data_bigarray_val(x_value);
  double *y = Data_bigarray_val(y_value);
  double *z = Data_bigarray_val(z_value);
  int size = Int_val(size_value);
  double tot = 0;
  int i;
  for(i=0; i < size; i++) {
    tot += x[i] * y[i] * z[i];
  }
  ml_tot = caml_copy_double(tot);
  CAMLreturn(ml_tot);
}


CAMLprim value quad_dot_c(value x_value, value y_value, value z_value, value w_value, value size_value)
{
  CAMLparam5(x_value, y_value, z_value, w_value, size_value);
  CAMLlocal1(ml_tot);
  double *x = Data_bigarray_val(x_value);
  double *y = Data_bigarray_val(y_value);
  double *z = Data_bigarray_val(z_value);
  double *w = Data_bigarray_val(w_value);
  int size = Int_val(size_value);
  double tot = 0;
  int i;
  for(i=0; i < size; i++) {
    tot += x[i] * y[i] * z[i] * w[i];
  }
  ml_tot = caml_copy_double(tot);
  CAMLreturn(ml_tot);
}

CAMLprim value pairwise_prod_c(value dest_value, value x_value, value y_value, value size_value)
{
  CAMLparam4(dest_value, x_value, y_value, size_value);
  double *dest = Data_bigarray_val(dest_value);
  double *x = Data_bigarray_val(x_value);
  double *y = Data_bigarray_val(y_value);
  int size = Int_val(size_value);
  int i;
  for(i=0; i < size; i++) {
    dest[i] = x[i] * y[i];
  }
  CAMLreturn(Val_unit);
}

CAMLprim value triplewise_prod_c(value dest_value, value x_value, value y_value, value z_value, value size_value)
{
  CAMLparam5(dest_value, x_value, y_value, z_value, size_value);
  double *dest = Data_bigarray_val(dest_value);
  double *x = Data_bigarray_val(x_value);
  double *y = Data_bigarray_val(y_value);
  double *z = Data_bigarray_val(z_value);
  int size = Int_val(size_value);
  int i;
  for(i=0; i < size; i++) {
    dest[i] = x[i] * y[i] * z[i];
  }
  CAMLreturn(Val_unit);
}
