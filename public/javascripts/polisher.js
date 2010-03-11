// polisher javascript methods

// send a http delete request
function delete_request(uri, callback){
  $.ajax({
      url: uri,
      type: 'DELETE',
      success: callback
  });
}

// reload page
function reload(){
  location.reload(true);
}
