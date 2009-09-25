function poll_server() {
  $('#log').load(
    '/pushstream/',
    function(){poll_server();}
  );
}
$(function(){
  poll_server();
});
