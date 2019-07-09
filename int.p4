#include <core.p4>
#include <v1model.p4>


/*************************************************************************
************** C O N S T A N T   D E C L A R A T I O N  *****************
*************************************************************************/

const bit<16> ETHERTYPE_IPV4  = 0x0800;
const bit<8>  PROTOCOL_UDP    = 0x11;
const bit<5>  IPV4_OPTION_INT = 31;

#define MAX_HOPS 3

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/
typedef bit<9> egress_spec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ipv4Addr_t;
typedef bit<32> qdepth_t;
typedef bit<32> switchID_t;

header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}


header ipv4_t {
    bit<4>     version;
    bit<4>     ihl;
    bit<8>     dscp;
    bit<16>    totalLength;
    bit<16>    identification;
    bit<3>     flags;
    bit<13>    fragmentOffset;
    bit<8>     ttl;
    bit<8>     protocol;
    bit<16>    headerChecksum;
    ipv4Addr_t srcAddr;
    ipv4Addr_t dstAddr;
}


header ipv4_option_t {
    bit<1> copyFlag;
    bit<2> optionClass;
    bit<5> optionNumber;
    bit<8> optionLength;
}

header int_header_t {
    bit<16> numberOfValues;
}

header switch_t {
    switchID_t swid;
    qdepth_t qdepth;
}


struct int_metadata_t {
    bit<16> numberOfValues;
}

struct parser_metadata_t {
    bit<16> remaining;
}

struct metadata {
    int_metadata_t   ingress_metadata;
    parser_metadata_t   parser_metadata;
}

struct headers_t {
    ethernet_t            ethernet;
    ipv4_t                ipv4;
    ipv4_option_t         ipv4_option;
    int_header_t          int_header;
    switch_t[MAX_HOPS]    swtraces;
}



error { IPHeaderTooShort }
/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser IntParser(packet_in p,
                out headers_t hdr,
		inout metadata meta,
                inout standard_metadata_t sm) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        p.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            ETHERTYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        p.extract(hdr.ipv4);
        verify(hdr.ipv4.ihl >= 5, error.IPHeaderTooShort);
        transition select(hdr.ipv4.ihl) {
            5:       accept;
            default: parse_ipv4_option;
        }
    }

    state parse_ipv4_option {
        p.extract(hdr.ipv4_option);
        transition select(hdr.ipv4_option.optionNumber) {
            IPV4_OPTION_INT: parse_int_header;
            default:         accept;
        }
    }

    state parse_int_header {
        p.extract(hdr.int_header);
        meta.parser_metadata.remaining = hdr.int_header.numberOfValues;
        transition select(meta.parser_metadata.remaining) {
            0:       accept;
            default: parse_swtrace;
        }
    }
	
    state parse_swtrace {
        p.extract(hdr.swtraces.next);
        meta.parser_metadata.remaining = meta.parser_metadata.remaining  - 1;
        transition select(meta.parser_metadata.remaining) {
            0 : accept;
            default: parse_swtrace;
        }
   }
}

/*************************************************************************
************   C H E C K S U M    V E R I F I C A T I O N   *************
*************************************************************************/

control IntVerifyChecksum(inout headers_t hdr, inout metadata meta) {
    apply {  }
}


/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control IntIngress(inout headers_t hdr,
                   inout metadata meta,
		   inout standard_metadata_t sm) {


    action drop() {
        mark_to_drop();
    }

//    action IPv4Forwarding(egress_spec_t egress_spec) {
  //  sm.egress_spec = egress_spec;
   // hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    //}

    action IPv4Forwarding(macAddr_t dstAddr, egress_spec_t port) {
        sm.egress_spec = port;
        hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
        hdr.ethernet.dstAddr = dstAddr;
        hdr.ipv4.ttl = hdr.ipv4.ttl - 1;
    }
	
    table ipv4_lpm {
        key = {
            hdr.ipv4.dstAddr: lpm;
        }
        actions = {
            IPv4Forwarding;
	    drop;
            NoAction;
        }
        size = 1024;
	default_action = NoAction();
    }

    apply {
        if(hdr.ipv4.isValid()) {
            ipv4_lpm.apply();
        }
    }
}
/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/
control IntEgress(inout headers_t hdr,
                 inout metadata meta, 
		 inout standard_metadata_t sm) {
	action add_swtrace(switchID_t swid) { 
        	hdr.int_header.numberOfValues = hdr.int_header.numberOfValues + 1;
		hdr.swtraces.push_front(1);
		hdr.swtraces[0].setValid();
		hdr.swtraces[0].swid = swid;
		hdr.swtraces[0].qdepth = (qdepth_t)sm.deq_qdepth;

		hdr.ipv4.ihl = hdr.ipv4.ihl + 2;
        	hdr.ipv4_option.optionLength = hdr.ipv4_option.optionLength + 8; 
		hdr.ipv4.totalLength = hdr.ipv4.totalLength + 8;
		}

	table swtrace {
        actions = { 
	    add_swtrace; 
	    NoAction; 
        }
        default_action = NoAction();      
    }
    
    apply {
        if (hdr.int_header.isValid()) {
            swtrace.apply();
        }
    }
}

/*************************************************************************
*************   C H E C K S U M    C O M P U T A T I O N   **************
*************************************************************************/

control IntComputeChecksum(inout headers_t hdr, inout metadata meta) {
     apply {
	update_checksum(
	    hdr.ipv4.isValid(),
            { hdr.ipv4.version,
	      hdr.ipv4.ihl,
              hdr.ipv4.dscp,
              hdr.ipv4.totalLength,
              hdr.ipv4.identification,
              hdr.ipv4.flags,
              hdr.ipv4.fragmentOffset,
              hdr.ipv4.ttl,
              hdr.ipv4.protocol,
              hdr.ipv4.srcAddr,
              hdr.ipv4.dstAddr },
            hdr.ipv4.headerChecksum,
            HashAlgorithm.csum16);
    }
}
/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/

control IntDeparser(packet_out p, in headers_t hdr) {
    apply {
        p.emit(hdr.ethernet);
        p.emit(hdr.ipv4);
	p.emit(hdr.ipv4_option);
	p.emit(hdr.int_header);
	p.emit(hdr.swtraces);
    }
}

/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/

V1Switch(
IntParser(),
IntVerifyChecksum(),
IntIngress(),
IntEgress(),
IntComputeChecksum(),
IntDeparser()
) main;
