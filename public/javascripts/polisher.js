// polisher javascript methods

// send a http delete request
function delete_request(uri, callback){
  $.ajax({
      url: uri,
      type: 'DELETE',
      success: callback
  });
}

function post_request(uri, params, callback){
  $.ajax({
      url: uri,
      type: 'POST',
      data: params,
      success: callback
  });
}

function handle_request_result(result){
  res = $(result)
  alert(res.find("message").text().trim());
  if(res.find("success").text().trim() == "true"){
    reload();
  }
}

// reload page
function reload(){
  location.reload(true);
}
