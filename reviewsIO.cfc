component {
	cfprocessingdirective( preserveCase=true );

	function init(
		required string store
	,	required string apiKey
	,	required string apiUrl= "https://api.reviews.co.uk"
	,	numeric httpTimeOut= 120
	,	boolean debug= ( request.debug ?: false )
	) {
		this.store= arguments.store;
		this.apiKey= arguments.apiKey;
		this.apiUrl= arguments.apiUrl;
		this.httpTimeOut= arguments.httpTimeOut;
		this.debug= arguments.debug;
		return this;
	}

	function debugLog( required input ) {
		if ( structKeyExists( request, "log" ) && isCustomFunction( request.log ) ) {
			if ( isSimpleValue( arguments.input ) ) {
				request.log( "reviews-io: " & arguments.input );
			} else {
				request.log( "reviews-io: (complex type)" );
				request.log( arguments.input );
			}
		} else if( this.debug ) {
			cftrace( text=( isSimpleValue( arguments.input ) ? arguments.input : "" ), var=arguments.input, category="reviews-io", type="information" );
		}
		return;
	}

	function getLatestServiceReviews() {
		return this.apiRequest( api= "GET /merchant/latest" );
	}

	function getServiceReviews(
		numeric per_page= 25
	,	numeric page= 0
	,	string order_number= ""
	,	string min_rating= ""
	,	string max_rating= ""
	,	string min_date= ""
	,	string max_date= ""
	,	string include_replies= ""
	,	string order= "asc"
	) {
		arguments.min_date= this.apiDateFormat( arguments.min_date );
		arguments.max_date= this.apiDateFormat( arguments.max_date );
		return this.apiRequest( api= "GET /merchant/reviews", args= arguments );
	}

	function getInvitation( numeric page= 0 ) {
		return this.apiRequest( api= "GET /merchant/invitation", args= arguments );
	}

	function deleteInvitation( required string id ) {
		return this.apiRequest( api= "DELETE /merchant/invitation/{id}", args= arguments );
	}

	function getOrderReview( required string order_number ) {
		return this.apiRequest( api= "GET /merchant/reviews", args= arguments );
	}

	function emailInvitation(
		required string name
	,	required string email
	,	required numeric order_id
	,	date date_send
	,	string delay
	,	string branch
	,	string template_id
	,	string tags= ""
	) {
		if ( structKeyExists( arguments, "date_send" ) ) {
			arguments.date_send= this.apiDateFormat( arguments.date_send );
		}
		return this.apiRequest( api= "POST /merchant/invitation", args= arguments );
	}

	function smsInvitation(
		required string name
	,	required string mobile_number
	,	required numeric order_id
	,	string message= "Hi [name]! We'd love to hear what you think about your recent experience with [DomainName]. You can leave a review by following this link: [link]"
	,	date date_send
	,	string delay
	,	string branch
	,	string tags= ""
	) {
		if ( structKeyExists( arguments, "date_send" ) ) {
			arguments.date_send= this.apiDateFormat( arguments.date_send );
		}
		return this.apiRequest( api= "POST /merchant/sms/invitation", args= arguments );
	}

	function addProductReview(
		required string sku
	,	required string name
	,	string email
	,	string review
	,	numeric rating
	,	numeric order_id
	,	struct ratings
	,	string address
	,	string date_created= ""
	) {
		arguments.date_created= this.apiDateFormat( arguments.date_created );
		return this.apiRequest( api= "POST /product/review/new", args= arguments );
	}

	function getProductReviews( numeric per_page= 25, numeric page= 0 ) {
		return this.apiRequest( api= "GET /product/reviews/all", args= arguments );
	}

	function apiDateFormat(required string date) {
		if ( len( arguments.date ) && isDate( arguments.date ) ) {
			arguments.date= replace( dateTimeFormat( arguments.date_created, "yyyy-mm-dd HH:nn:ss" ), " ", "T" );
		} else {
			arguments.date= "";
		}
		return arguments.date;
	}

	struct function apiRequest( required string api, json= "", args= "" ) {
		var http= {};
		var dataKeys= 0;
		var item= "";
		var out= {
			success= false
		,	error= ""
		,	status= ""
		,	json= ""
		,	statusCode= 0
		,	response= ""
		,	verb= listFirst( arguments.api, " " )
		,	requestUrl= this.apiUrl & listRest( arguments.api, " " )
		,	args= arguments.args
		};
		out.args.store= this.store;
		out.args.apiKey= this.apiKey;
		if ( isStruct( arguments.json ) ) {
			out.json= serializeJSON( arguments.json );
			out.json= reReplace( out.json, "[#chr(1)#-#chr(7)#|#chr(11)#|#chr(14)#-#chr(31)#]", "", "all" );
		} else if ( isSimpleValue( arguments.json ) && len( arguments.json ) ) {
			out.json= arguments.json;
		}
		//  copy args into url 
		if ( isStruct( out.args ) ) {
			//  replace {var} in url 
			for ( item in out.args ) {
				//  strip NULL values 
				if ( isNull( out.args[ item ] ) ) {
					structDelete( out.args, item );
				} else if ( isSimpleValue( out.args[ item ] ) && out.args[ item ] == "null" ) {
					out.args[ item ]= javaCast( "null", 0 );
				} else if ( findNoCase( "{#item#}", out.requestUrl ) && structKeyExists( this, item ) ) {
					out.requestUrl= replaceNoCase( out.requestUrl, "{#item#}", this[ item ], "all" );
				} else if ( findNoCase( "{#item#}", out.requestUrl ) ) {
					out.requestUrl= replaceNoCase( out.requestUrl, "{#item#}", out.args[ item ], "all" );
					structDelete( out.args, item );
				}
			}
			out.requestUrl &= this.structToQueryString( out.args );
		}
		this.debugLog( out.requestUrl );
		// this.debugLog( out );
		cftimer( type="debug", label="reviews-io request" ) {
			cfhttp( result="http", method=out.verb, url=out.requestUrl, charset="UTF-8", throwOnError=false, timeOut=this.httpTimeOut ) {
				if ( out.verb == "POST" || out.verb == "PUT" ) {
					// cfhttpparam( type="header", name="store", value= this.store );
					// cfhttpparam( type="header", name="apikey", value= this.apiKey );
					cfhttpparam( name="Content-Type", type="header", value="application/json" );
					cfhttpparam( type="body", value=out.json );
				}
			}
		}
		// this.debugLog( http )> 
		out.response= toString( http.fileContent );
		// this.debugLog( out.response );
		out.statusCode= http.responseHeader.Status_Code ?: 500;
		this.debugLog( out.statusCode );
		if ( left( out.statusCode, 1 ) == 4 || left( out.statusCode, 1 ) == 5 ) {
			out.success= false;
			out.error= "status code error: #out.statusCode#";
		} else if ( out.response == "Connection Timeout" || out.response == "Connection Failure" ) {
			out.error= out.response;
		} else if ( left( out.statusCode, 1 ) == 2 ) {
			out.success= true;
		}
		//  parse response 
		if ( len( out.response ) ) {
			try {
				out.response= deserializeJSON( replace( out.response, ':null', ':""', 'all' ) );
				if ( isStruct( out.response ) && structKeyExists( out.response, "success" ) && out.response.success == false ) {
					out.success= false;
					out.error= out.response.message;
				}
			} catch (any cfcatch) {
				out.error= "JSON Error: " & cfcatch.message & " " & cfcatch.detail;
			}
		}
		if ( len( out.error ) ) {
			out.success= false;
		}
		return out;
	}

	string function structToQueryString( required struct stInput, boolean bEncode= true, string lExclude= "", string sDelims= "," ) {
		var sOutput= "";
		var sItem= "";
		var sValue= "";
		var amp= "?";
		for ( sItem in stInput ) {
			if ( !len( lExclude ) || !listFindNoCase( lExclude, sItem, sDelims ) ) {
				try {
					sValue= stInput[ sItem ];
					if ( len( sValue ) ) {
						if ( bEncode ) {
							sOutput &= amp & lCase( sItem ) & "=" & urlEncodedFormat( sValue );
						} else {
							sOutput &= amp & lCase( sItem ) & "=" & sValue;
						}
						amp= "&";
					}
				} catch (any cfcatch) {
				}
			}
		}
		return sOutput;
	}

}
