#ifndef BARCODE_UTILS
#define BARCODE_UTILS

#include <cstdio>
#include <cassert>
#include <cstdint>
#include <string>
#include <fstream>
#include <vector>
#include <unordered_map>

#include "gzip_utils.hpp"

struct ValueType {
	int item_id;
	char n_mis; // number of mismatches

	ValueType() : item_id(-1), n_mis(0) {}
	ValueType(int item_id, char n_mis) : item_id(item_id), n_mis(n_mis) {}
};

typedef std::unordered_map<uint64_t, ValueType> HashType;
typedef HashType::iterator HashIterType;

const int STEP = 3;
const int BASE = 7;
const int UPPER = 21;
const int NNUC = 5; // ACGTN

const char id2base[NNUC] = {'A', 'C', 'G', 'T', 'N'};

// Assume char's range is -128..127
const int CHAR_RANGE = 128;
static std::vector<int> init_base2id() {
	std::vector<int> vec(CHAR_RANGE, -1);
	vec['a'] = vec['A'] = 0;
	vec['c'] = vec['C'] = 1;
	vec['g'] = vec['G'] = 2;
	vec['t'] = vec['T'] = 3;
	vec['n'] = vec['N'] = 4;

	return vec;
}

static const std::vector<int> base2id = init_base2id();



static std::vector<std::vector<uint64_t> > init_aux_arr() {
	std::vector<std::vector<uint64_t> > aux_arr;
	for (int i = 0; i < UPPER; ++i) {
		std::vector<uint64_t> arr(NNUC + 1, 0);
		for (uint64_t j = 0; j < NNUC; ++j) arr[j] = j << (STEP * i);
		arr[NNUC] = uint64_t(BASE) << (STEP * i);
		aux_arr.push_back(arr);
	}
	return aux_arr;
}

static const std::vector<std::vector<uint64_t> > aux_arr = init_aux_arr();

uint64_t barcode_to_binary(const std::string& barcode) {
	uint64_t binary_id = 0;
	char c;
	if (barcode.length() > UPPER) printf("%s\n", barcode.c_str());
	assert(barcode.length() <= UPPER);
	for (auto&& it = barcode.rbegin(); it != barcode.rend(); ++it) {
		c = *it;
		assert(base2id[c] >= 0);
		binary_id <<= STEP;
		binary_id += base2id[c];
	}
	return binary_id;
}

std::string binary_to_barcode(uint64_t binary_id, int len) {
	std::string barcode(len, 0);
	for (int i = 0; i < len; ++i) {
		barcode[i] = id2base[binary_id & BASE];
		binary_id >>= STEP;
	}
	return barcode;
}

inline bool insert(HashType& index_dict, uint64_t key, ValueType&& value) {
	std::pair<HashIterType, bool> ret;
	ret = index_dict.insert(std::make_pair(key, value));
	if (ret.second) return true;
	assert(ret.first->second.n_mis > 0 && value.n_mis > 0);
	ret.first->second.item_id = -1;
	return false;
}

inline void mutate_index_one_mismatch(HashType& index_dict, std::string& barcode, int item_id) {
	int len = barcode.length();
	uint64_t binary_id = barcode_to_binary(barcode);

	insert(index_dict, binary_id, ValueType(item_id, 0));
	for (int i = 0; i < len; ++i) {
		uint64_t val = binary_id & aux_arr[i][NNUC];
		for (int j = 0; j < NNUC; ++j)
			if (val != aux_arr[i][j]) {
				insert(index_dict, binary_id - val + aux_arr[i][j], ValueType(item_id, 1));
			} 
	}
}

inline void mutate_index(HashType& index_dict, uint64_t binary_id, int len, int item_id, int max_mismatch, int mismatch, int pos) {
	insert(index_dict, binary_id, ValueType(item_id, mismatch));
	if (mismatch >= max_mismatch) return;

	for (int i = pos; i < len; ++i) {
		uint64_t val = binary_id & aux_arr[i][NNUC];
		for (int j = 0; j < NNUC; ++j)
			if (val != aux_arr[i][j]) {
				mutate_index(index_dict, binary_id - val + aux_arr[i][j], len, item_id, max_mismatch, mismatch + 1, i + 1);
			}
	}
}

void parse_sample_sheet(const char* sample_sheet_file, int& n_barcodes, int& barcode_len, HashType& index_dict, std::vector<std::string>& index_names, int max_mismatch = 1) {
	iGZipFile fin(sample_sheet_file);
	std::string line, index_name, index_seq;

	n_barcodes = 0;
	index_dict.clear();
	index_names.clear();
	while (fin.next(line)) {
		std::size_t pos = line.find_first_of(',');
		if (pos != std::string::npos) { index_seq = line.substr(0, pos); index_name = line.substr(pos + 1); }
		else { index_seq = line; index_name = line; }
		if (max_mismatch == 1) mutate_index_one_mismatch(index_dict, index_seq, n_barcodes);
		else mutate_index(index_dict, barcode_to_binary(index_seq), index_seq.length(), n_barcodes, max_mismatch, 0, 0);
		index_names.push_back(index_name);
		++n_barcodes;
	}
	fin.close();

	barcode_len = index_seq.length();
	printf("%s is parsed. n_barcodes = %d, and barcode_len = %d.\n", sample_sheet_file, n_barcodes, barcode_len);

	int n_amb = 0;
	for (auto&& kv : index_dict) 
		if (kv.second.item_id < 0) ++n_amb;
	printf("In the index, %d out of %d items are ambigious, ratio = %.2f.\n", n_amb, (int)index_dict.size(), n_amb * 1.0 / index_dict.size());
}

#endif 
