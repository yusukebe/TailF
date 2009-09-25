var timer;
function poll_server() {
  $('#log').load('/pushstream/');
}
function setTimer(){
  timer = setInterval("poll_server()", 1000);
}
$(function(){
  setTimer();
  $('a').hover(
    function(){
      clearInterval(timer);
    },
    function(){
      setTimer();
    }
  );
});
