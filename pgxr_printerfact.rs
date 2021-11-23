//#[macro_use]
extern crate pgxr;
extern crate reqwest;
use pgxr::bindings::*;
use pgxr::*;
PG_MODULE_MAGIC!();

PG_FUNCTION_INFO_V1!(pg_finfo_pgxr_printerfact);

#[no_mangle]
pub extern "C" fn pgxr_printerfact(_fcinfo: FunctionCallInfo) -> Datum {
    let resp = reqwest::blocking::get("https://colbyolson.com/printers")
        .unwrap()
        .text()
        .unwrap();
    PG_RETURN_TEXT(resp)
}
