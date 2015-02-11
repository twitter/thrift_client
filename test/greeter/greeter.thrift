exception OopsException {
  1: string message
}
service Greeter {
  string greeting(1:string name)
  oneway void yo(1:string name)
  void oops() throws (1: OopsException a);
}
